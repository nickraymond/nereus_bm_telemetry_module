# DESIGN.md — Architecture & Decisions (as-built)

*What it did / how it's shaped. Agents append; never silently rewrite history.*
*Last updated: 2026-10-08*

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
