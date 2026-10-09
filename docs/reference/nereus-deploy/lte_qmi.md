<!-- Verbatim copy of nickraymond/nereus-deploy main:manual_steps/lte_qmi.md, fetched 2026-10-08.
     Source: https://github.com/nickraymond/nereus-deploy/blob/main/manual_steps/lte_qmi.md
     The installer that pauses on this checkpoint is install.sh in the same repo (run_manual_lte_checkpoint).
     Validated again on nereus001 (Pi 5) 2026-10-08, see docs/DESIGN.md Bench results. -->

# LTE modem bring-up / AT&T QMI validation

Goal: keep LTE bring-up simple and repeatable. The installer installs the required tools and verifies the modem is visible. The actual carrier/APN registration step is manual so you can see exactly what the Telit modem is doing.

This procedure matches the currently proven working sequence for the Telit LE910C4-NF on Sixfab:

- set the PDP/APN profile with AT commands
- force AT&T LTE operator selection
- reboot the modem
- restart ModemManager / NetworkManager
- create the NetworkManager `lte` profile
- validate `wwan0`

## 1. Verify USB hardware enumeration

```bash
lsusb
lsusb -t
ls -l /dev/ttyUSB* /dev/cdc-wdm* 2>/dev/null || true
lsmod | grep -E 'qmi|wwan|cdc_wdm|option|usbserial'
```

Expected success signs:

```text
Telit Wireless Solutions LE910 / LE920
/dev/cdc-wdm0
/dev/ttyUSB2
qmi_wwan
cdc_wdm
```

`cdc-wdm0` is the QMI/control interface. `wwan0` is the packet data interface.

## 2. Stop services before using the AT port

```bash
sudo nmcli connection down lte 2>/dev/null || true
sudo systemctl stop ModemManager NetworkManager
```

## 3. Open the AT terminal

Usually the AT port is `/dev/ttyUSB2` on this modem:

```bash
sudo minicom -D /dev/ttyUSB2 -b 115200
```

If `AT` does not return `OK`, exit minicom with `Ctrl-A`, then `X`, and try `/dev/ttyUSB3`.

## 4. Configure APN and force AT&T LTE

Inside minicom:

```text
AT
AT+CPIN?
AT+CGDCONT?
AT+CGDCONT=1,"IP","iot0723.com.attz"
AT+CGDCONT?
AT+COPS=?
AT+COPS=2
AT+COPS=1,2,"310410",7
AT+COPS?
AT+CEREG?
AT+CGATT?
AT#REBOOT
```

Expected good state before reboot:

```text
+COPS: 1,2,"310410",7
+CEREG: 0,1
+CGATT: 1
```

Notes:

- `310410` is AT&T.
- `7` means LTE/E-UTRAN.
- If `310410` fails but scan shows `313100` as AT&T, test `AT+COPS=1,2,"313100",7`.
- `AT#REBOOT` is important. It lets the modem come back cleanly so ModemManager sees the configured APN/operator state.

Exit minicom with `Ctrl-A`, then `X`.

## 5. Restart ModemManager / NetworkManager

```bash
sudo systemctl start ModemManager NetworkManager
sleep 30

mmcli -L
mmcli -m 0
```

Expected good state:

```text
state: connected
access tech: lte
operator id: 310410
operator name: AT&T
registration: home
packet service state: attached
initial bearer apn: iot0723.com.attz
initial bearer ip type: ipv4
```

## 6. Create/recreate the LTE NetworkManager profile

```bash
sudo nmcli connection down lte 2>/dev/null || true
sudo nmcli connection delete lte 2>/dev/null || true
sudo nmcli connection add type gsm ifname cdc-wdm0 con-name lte apn iot0723.com.attz
sudo nmcli connection modify lte gsm.network-id 310410
sudo nmcli connection modify lte ipv4.method auto ipv6.method ignore
sudo nmcli connection modify lte connection.autoconnect yes
sudo nmcli connection up lte
```

## 7. Verify LTE data path

```bash
ip a show wwan0
ip route
ping -I wwan0 -c 5 1.1.1.1
curl --interface wwan0 --max-time 20 https://nereus-vision-staging.onrender.com/
```

Expected:

```text
wwan0 is UP and has an IPv4 address
ping -I wwan0 has 0% packet loss
curl reaches the backend
```

A successful backend response looks like:

```json
{"status":"ok","message":"Nereus Vision API running"}
```

## 8. Troubleshooting notes

If `wwan0` is down and `mmcli -m 0` shows `registration: searching` or `packet service state: detached`, the modem is not registered/attached. Go back to the AT step and confirm:

```text
+COPS: 1,2,"310410",7
+CEREG: 0,1
+CGATT: 1
```

If ModemManager shows `failed reason: unknown-capabilities` after manual AT changes, reboot the modem with `AT#REBOOT`, then restart ModemManager and NetworkManager.

Do not use automatic carrier selection for this deployment unless intentionally testing a roaming fallback. The intended locked carrier path is AT&T `310410` with APN `iot0723.com.attz`.
