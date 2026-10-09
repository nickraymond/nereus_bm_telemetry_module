# PROVISION_PI.md — fresh Pi to working LTE uplink

*The workflow used on nereus001 on 2026-10-08, as it should be re-run on the
Pi Zero 2W. One command does it; this page says what each step proves and
what a failure at each step means.*

## Before you start

- Pi flashed, on Wi-Fi (for apt) and reachable over ssh; `sudo -n true` works.
- SIM in the HAT, LTE antenna on **M** (D = diversity, G = GPS). Never power
  the modem without the M antenna.
- HAT USB cable into the Pi (or the hub on the Zero). Use a cable known to
  carry data; a charge-only cable makes a good modem look dead.
- Hot-plugging the HAT's USB is fine. Only the 40-pin header must be seated
  with the Pi off.

## Run

```bash
scp tools/*.sh tools/*.py pi@<host>:~/
ssh pi@<host> 'sudo ./provision_lte.sh'
```

Optional env on the ssh line: `APN=…` `PLMN=…` `PROBE_URL=…`.

## What the script does and what each step proves

| Step | Does | Pass looks like | If it fails |
|---|---|---|---|
| 1 packages | apt modemmanager, libqmi-utils, minicom, usbutils; enable ModemManager | versions printed | no internet on the Pi |
| 2 USB | waits up to 2 min for `1bc7:1201` | Telit line from lsusb | HAT power, USB data cable, or modem |
| 3 board check | `sixfab_board_check.sh`: ttyUSB0–4, cdc-wdm0, AT on ttyUSB3, MM sees the modem | `AT answered on /dev/ttyUSB3` | enumerated but mute = modem firmware/serial |
| 4 carrier lock | stops MM+NM; `lte_att_bringup.py` sets APN on ctx 1, `COPS=2`, `COPS=1,2,"310410",7`, waits for CEREG 1, `AT#REBOOT` | `PASS: registered on 310410` | `#CEERNET: 15` = SIM not accepted on that APN/plan; `CSQ 99,99` = no antenna/coverage |
| 5 ModemManager | waits for state connected/registered | `registration: home`, bearer APN correct | wait longer once; else back to step 4 |
| 6 NM profile | creates/updates `lte` (gsm, cdc-wdm0, APN, network-id, IPv6 off, autoconnect) and brings it up | wwan0 has a 10.x/28 address, default route metric 700 | `nmcli device` shows cdc-wdm0 disconnected: journalctl -u NetworkManager |
| 7 data | ping 1.1.1.1 and curl the staging root over wwan0 only; writes `~/lte_provision_<UTC>.json` | `PASS: LTE uplink working`, HTTP 200 | HTTP 000 with ping OK = DNS/TLS over wwan0; both fail = bearer up but no route |

## After it passes

- Keep the JSON. It is the unit's inventory record (IMEI, ICCID, IMSI, operator, signal, IP).
- Re-running the script is safe; step 4 rewrites the same values and reboots the modem once.
- Read-only status at any time (stop MM first):
  `sudo systemctl stop ModemManager && sudo python3 ~/lte_att_bringup.py --status; sudo systemctl start ModemManager`
- Undo on a bench unit: `sudo nmcli connection delete lte; sudo systemctl disable --now ModemManager`.
  The modem keeps the APN/operator lock in its own NVM; `AT+COPS=0` restores automatic selection.

## Known differences to watch on the Pi Zero 2W (S0b)

- USB goes through a hub; confirm the modem's five ttyUSB ports and cdc-wdm0 still appear (step 3).
- Power: the modem's transmit peaks share the Zero's 5 V path with the hub. Watch for USB disconnects in `dmesg` during step 7 (SPEC Q1).
- OS: nereus001 is Trixie / kernel 6.18 / ModemManager 1.24. Record the Zero's versions in DESIGN §Bench (SPEC Q5).
