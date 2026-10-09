# SPEC.md — nereus_bm_telemetry_module

*What Nick Buemond wants. Stable reference — agents skim this; changes require Nick's approval.*
*Last updated: 2026-10-08*

## Goal

A Bristlemouth node that gives the rest of the bus a cellular uplink and
downlink. End-state demo: Nick sends a command from the nereus-vision
dashboard; it reaches this module over LTE, crosses the Bristlemouth bus to a
camera node in a pool, the camera records a 30 s clip, and the clip comes back
through the module over LTE and appears on the dashboard.

## Background

Today the cameras (bm_cam_legacy) transmit through a Sofar Spotter's cellular
link at roughly one small message per second with a hard per-report budget,
so a 30 s clip takes many wakes and heals. A module with its own modem sends
far more bytes per radio-on second, so the same media costs less energy and
arrives sooner, and commands can reach the bus without waiting for the
Spotter's report cycle. The LTE bring-up itself is already proven on the
nereus-vision field camera (nickraymond/nereus-deploy); this repo reuses that
path and adds the Bristlemouth side.

## Inventory / environment

| Item | Qty | Role |
|---|---|---|
| Raspberry Pi 5 "nereus001" (Trixie, kernel 6.18) | 1 | bench/dev unit, LTE validated 2026-10-08 |
| Raspberry Pi Zero 2W + USB hub (hub stack tested by Nick) | 1 | field target, provisioning due 2026-10-09 |
| Sixfab Base HAT (mini-PCIe, USB to Pi) | 1 | modem carrier; verified not damaged 2026-10-08 |
| Telit LE910C4-NF, USB 1bc7:1201, fw 25.21.664 / M0F.660014, hw 1.30 | 1 | LTE Cat-4 modem, carrier image slot 0 (AT&T) |
| AT&T IoT SIM, IMSI 310170…, ICCID 8901170…4866 | 1 | APN iot0723.com.attz |
| LTE antenna on M (D, G unconnected) | 1 | RX/TX; GPS antenna not yet fitted |
| Bristlemouth mote + bus power (dev rig) | — | power + UART peer; not yet connected to this module |
| nereus-vision staging backend | — | https://nereus-vision-staging.onrender.com/ |

## Confirmed facts (verified, with sources)

1. The HAT + modem enumerate on USB as QMI (`AT#USBCFG: 0`): ttyUSB0–4,
   cdc-wdm0, wwan0. AT answers on ttyUSB2 and ttyUSB3; ModemManager owns
   ttyUSB2 at runtime. *Source: nereus001 dmesg + tools/sixfab_board_check.sh, 2026-10-08.*
2. With the firmware-default APN table (`nxtgenphone`, `ims`, `sos`,
   `attm2mglobal`) the SIM is rejected by AT&T 310410 with EMM cause 15, in
   both automatic and forced selection, while AT&T is visible at RSRP −76 dBm.
   *Source: AT#CEERNET / AT+COPS=? on nereus001, 2026-10-08.*
3. The nereus-deploy sequence (APN on context 1 → `AT+COPS=2` →
   `AT+COPS=1,2,"310410",7` → `AT#REBOOT`) registers in ~60 s; after reboot
   ModemManager reports connected, home, LTE. *Source: tools/lte_att_bringup.py
   run 2026-10-08; docs/reference/nereus-deploy/lte_qmi.md.*
4. NetworkManager gsm profile on cdc-wdm0 gives wwan0 a /28 carrier address and
   a default route at metric 700 (Wi-Fi stays primary at 600). Ping 1.1.1.1
   over wwan0: 4/4, ~75 ms RTT. Staging backend over wwan0: HTTP 200 in 0.27 s.
   *Source: provision run on nereus001, 2026-10-08.*
5. Modem reboot (`AT#REBOOT`) re-enumerates on USB in ~18–20 s. *Source: same run.*
6. The APN and manual operator lock live in the modem's NVM and survive Pi
   reboots. *Source: nereus-deploy lte_qmi.md; re-verified by ModemManager state
   after the reboot in fact 3.*
7. Visible PLMNs at Nick's bench: 310410 AT&T, 313100 FirstNet, 311480
   Verizon, 310260 T-Mobile. *Source: AT+COPS=?, 2026-10-08.*
8. mmcli signal polling (`--signal-setup=5`) is not persistent across modem
   reboots; the nereus-vision agent re-enables it at startup. *Source:
   nereus-vision-dev device/docs/lte_bringup_nereus_vision.md, Week 4 notes.*

## Safety / hard constraints (non-negotiable)

1. Power comes from the Bristlemouth bus and is cut without warning. Nothing
   may depend on a clean shutdown; every write to the SD card is atomic or
   recoverable, and the modem's NVM carries its own config.
2. Never transmit with no antenna on M (power-amplifier damage).
3. Cellular bytes cost money: every upload is sized, logged and bounded by a
   per-cycle budget before it is sent. No unbounded retries.
4. Field cameras and Spotters are not test targets. Bench only: nereus001,
   the Pi Zero 2W build, bmcam003/bmcam004 and the bench Spotters.
5. Raw AT on ttyUSB2/3 only with ModemManager stopped, and it is restarted after.

## Success criteria by sprint

See docs/TRACKER.md ladder. Each sprint's demo is the criterion.

## Non-goals (for now)

- Carriers other than AT&T. - GPS fixes. - Replacing the Spotter path on
  existing cameras. - Live video beyond a short, bounded test (S5+).

## Open questions (flag, don't guess)

- Q1 Bus power budget: the LE910C4 draws up to ~2 A peaks at 3.8 V on the HAT
  rail; what can the Bristlemouth bus and the Pi Zero's 5 V path supply? Needs
  a measurement, not a datasheet guess. Nick has a bench supply with a current readout (2026-10-08); measure in S0b.
- Q2 Halt/wake policy: optional halt like the camera's `power_halt`? When is
  the modem "not in use"? Decide after S1 measures a real upload's energy.
- Q3 Routing: on the field unit wwan0 is the only uplink; on bench units Wi-Fi
  wins at metric 600. Make the metric a provisioning option when it matters.
- Q4 Command path: nereus-vision API (poll or push?) and/or Sofar command API.
  The backend already has a device command log and remote-config endpoints
  (nereus-vision-dev Sprint26/27); confirm what the module can poll.
- Q5 Pi Zero 2W image: Bookworm or Trixie, 32- or 64-bit; does qmi_wwan +
  ModemManager 1.2x behave the same as on nereus001's Trixie/6.18 kernel?
- Q6 OTA updates for this module and the camera: mechanism TBD (git pull over
  LTE was tested once in nereus-vision-dev, commit 6e0e32b).
- Q7 Data cost per MB on the AT&T IoT plan, to size the S1 upload budget.
