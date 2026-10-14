# DESIGN.md — Architecture & Decisions (as-built)

*What it did / how it's shaped. Agents append; never silently rewrite history.*
*Last updated: 2026-10-14*

## System topology

```
 Bristlemouth bus (power + data)
   │
   ├── camera node(s) (bm_cam_legacy)        ── publish clips / images, take commands
   │
   └── THIS MODULE (pass-through node)
         mote ──UART── Pi Zero 2W ──USB hub── Sixfab Base HAT ── Telit LE910C4-NF ──LTE── nereus-vision backend
                        │                          (wwan0 via qmi_wwan, ModemManager + NetworkManager profile "lte")
                        └── optional halt between uses (Q2)
```

As built today (S0): only the right-hand half exists, on nereus001 (Pi 5).
The mote/UART half is S2.

## Key designs

- **Modem path = QMI + ModemManager + NetworkManager**, as on the
  nereus-vision field camera. No Sixfab userland. `AT#USBCFG` stays 0.
- **Carrier config lives in the modem NVM** (APN on context 1, manual operator
  lock 310410), written once by `tools/lte_att_bringup.py`. The Pi only needs
  the NetworkManager profile, which `tools/provision_lte.sh` creates.
- **Raw AT only with ModemManager stopped**, on ttyUSB3 (ttyUSB2 is MM's).
- **Every provisioning run leaves an artifact**: `~/lte_provision_<UTC>.json`
  with IMEI, ICCID, IMSI, operator, signal, wwan0 IP, ping and HTTP result.

## Decision log

| # | Date | Decision | Rationale |
|---|---|---|---|
| D1 | 2026-10-08 | Separate repo for the telemetry module | Distinct hardware, own release cadence, two consumer repos (camera + backend) |
| D2 | 2026-10-08 | Reuse nereus-deploy's manual LTE checkpoint verbatim, scripted | It is the proven path; the only failure seen today was skipping its APN step |
| D3 | 2026-10-08 | Keep modem in QMI mode (USBCFG 0), not ECM (USBCFG 4 in the older nereus-vision doc) | QMI enumerates wwan0 + cdc-wdm0 and ModemManager drives it; worked first time |
| D4 | 2026-10-08 | wwan0 default route metric 700 on bench units | Keeps Wi-Fi/Tailscale as the bench path; field policy is Q3 |
| D5 | 2026-10-08 | Record SIM/modem identifiers in the provisioning JSON, not in docs | Inventory belongs with the unit; docs keep partial IDs only |
| D6 | 2026-10-14 | On hosts that also carry Spotter consoles, ModemManager ignores 0483:5740 via a udev rule | MM 1.24 marks the STM32 CDC-ACM consoles `ID_MM_CANDIDATE=1`; probing would fight spotter-monitor for the port (nereus000) |
| D7 | 2026-10-14 | LTE is the fallback on nereus000: Ethernet 100 > Wi-Fi 600 > wwan0 700 (NM defaults, no metric override) | Nick: "LTE should be the fall back to wifi / ethernet"; the hil tools and pool-preview use the LAN address |

## Bench / test results

### 2026-10-08 — nereus001 (Pi 5, Trixie, 6.18.39), Sixfab Base HAT + LE910C4-NF, AT&T IoT SIM

| Step | Result |
|---|---|
| USB enumeration | 1bc7:1201 after 18 s; ttyUSB0–4, cdc-wdm0, wwan0 |
| AT (ttyUSB3) | ATI 332, fw M0F.660014, temp 25 °C, `#FWSWITCH: 0,0,0` |
| No SIM | `+CME ERROR: 10`, MM `sim-missing` (expected) |
| SIM, no antenna | CSQ 99,99, no cells; `AT#CSURV` error 660 |
| SIM + antenna on M, default APN | camps on Verizon B13 (RSRP −76); AT&T 310410 visible; forced 310410 rejected, `#CEERNET: 15`, CEREG 2,0 |
| APN iot0723.com.attz + COPS lock | CGATT 1 at 20 s, CEREG 1 at 60 s, `#RFSTS "310 410"` band 4/B2, RSRP −100 |
| After `AT#REBOOT` | re-enumerated in ~18 s; MM connected, home, LTE, 73 %, initial bearer APN correct |
| NM profile `lte` | wwan0 10.10.22.87/28, default via 10.10.22.88 metric 700 |
| Data | ping 1.1.1.1 4/4 avg 75 ms; staging HTTP 200 in 0.27 s; public IP 66.59.89.151 |

Board verdict: not damaged. Every layer passes.

### 2026-10-14 — nereus000 (Pi Zero 2 W, Trixie, 6.18.34, 4-port USB hub), same HAT + modem, new AT&T IoT SIM

Full record: `docs/provisioning/nereus000_20261014.md`.

| Step | Result |
|---|---|
| USB through the hub | 1bc7:1201 on hub port 1; ttyUSB0–4, cdc-wdm0, wwan0, same as nereus001; no USB errors in dmesg |
| Modem NVM after the move | APN + AT&T lock from nereus001 were still set; registered (CEREG 0,1) before any AT write |
| `provision_lte.sh` (unchanged) | PASS in 1 min 40 s; CEREG 1 at 20 s after forced COPS; MM registered 20 s after `AT#REBOOT` |
| Data | ping 1.1.1.1 4/4; staging HTTP 200; public IP 66.59.89.186 |
| Side effect | step 4 (NM stopped) removed wlan0's IP for ~35 s; eth0 kept its address |
| LTE-only, eth0 + wlan0 disconnected 120 s | default via wwan0 only; Mac `tailscale ping` via 66.59.89.186 at 177 ms; ssh over tailnet OK |
| Reboot (moved outdoors) | `lte` autoconnected; signal 100 % outdoors vs 67 % (RSRP −107/−110 dBm) indoors |
| Power (lifepo4wered-cli, Pi + hub + modem) | IOUT 0.40–0.64 A, peak 635 mA during provisioning; VIN ≥ 4.998 V; throttled 0x0 |
| Power, + both Spotters charging from the hub (outdoors, battery-fed) | 21-min watch, 40 samples (9:48–10:09 AM): VIN 5.025–5.056 V, IOUT 1.33–1.51 A, VBAT 3.631→3.637 V, throttled 0x0 throughout; consoles + LTE never dropped |
| Unexplained | Wi-Fi firmware crash (`brcmf_fw_crashed`, SDIO card removed) at the end of the apt install, before MM started; single event |

SPEC Q5 (Zero 2W image): Trixie 64-bit, kernel 6.18.34, ModemManager 1.24.0, libqmi 1.36.0; qmi_wwan behaves as on nereus001.
