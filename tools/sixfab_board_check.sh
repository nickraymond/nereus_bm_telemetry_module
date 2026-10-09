#!/usr/bin/env bash
# sixfab_board_check.sh - is a Sixfab LTE HAT + modem alive on this Pi?
#
# Purpose : one-shot go/no-go for a Sixfab Base HAT with a mini-PCIe modem
#           (Telit LE910C4 per device/docs/lte_bringup_nereus_vision.md in
#           nereus-vision-dev, or Quectel EC25). Enumeration -> serial ->
#           AT -> SIM -> registration, in that order, stopping at the first
#           failure so the failing layer is obvious.
# Inputs  : none. Optional env AT_PORT (default: auto, ttyUSB3 then ttyUSB2).
# Outputs : human-readable ladder on stdout; exit 0 only if AT answers OK.
# Assumes : ModemManager + libqmi-utils installed; passwordless sudo.
# Example : ssh pi@nereus001 'bash -s' < tools/sixfab_board_check.sh
# Limits  : SIM / registration steps are informational; a missing SIM or
#           antenna is not a damaged board. ModemManager is stopped for the
#           AT probe (it owns ttyUSB2 at runtime) and restarted after.
set -u
pass(){ echo "  PASS  $*"; }
fail(){ echo "  FAIL  $*"; }
info(){ echo "  info  $*"; }
hr(){ echo; echo "== $* =="; }

hr "1. USB enumeration (modem must appear here; if not: HAT power, USB data cable, or modem)"
usb=$(lsusb | grep -iE "telit|quectel|1bc7:|2c7c:" || true)
if [ -n "$usb" ]; then pass "$usb"; else fail "no Telit/Quectel device in lsusb"; lsusb; sudo -n dmesg | grep -iE "usb [0-9]|new .* device|cdc|option|qmi" | tail -8; exit 1; fi

hr "2. Serial + control ports"
ls -l /dev/ttyUSB* 2>/dev/null && pass "ttyUSB ports present" || fail "no /dev/ttyUSB* (option/usbserial driver not bound?)"
ls -l /dev/cdc-wdm* 2>/dev/null && pass "cdc-wdm present (QMI/MBIM control)" || info "no cdc-wdm (ok for ECM mode)"

hr "3. Raw AT probe (ModemManager paused so the port is free)"
sudo -n systemctl stop ModemManager
sleep 1
sudo -n python3 - <<'PY'
# Telit LE910C4 answers AT on ttyUSB2 and ttyUSB3 (ttyUSB2 is the one
# ModemManager owns at runtime). CME ERROR 10 on CPIN = no SIM inserted.
import os, termios, time, select, sys
cmds=["ATE0","ATI","AT+CGMR","AT+CPIN?","AT#SIMDET?","AT+CSQ","AT+CEREG?","AT#USBCFG?","AT#TEMPMON=1"]
ports=[os.environ.get("AT_PORT")] if os.environ.get("AT_PORT") else ["/dev/ttyUSB3","/dev/ttyUSB2","/dev/ttyUSB1"]
ok=False
for port in ports:
    if not os.path.exists(port): continue
    try:
        fd=os.open(port, os.O_RDWR|os.O_NOCTTY|os.O_NONBLOCK)
        a=termios.tcgetattr(fd); a[0]=0; a[1]=0; a[2]=termios.CS8|termios.CREAD|termios.CLOCAL; a[3]=0
        a[4]=a[5]=termios.B115200; termios.tcsetattr(fd, termios.TCSANOW, a)
    except Exception as e:
        print(f"  info  {port}: open failed: {e}"); continue
    for c in cmds:
        os.write(fd,(c+"\r").encode()); buf=b""; t=time.time()
        while time.time()-t<2.0:
            r,_,_=select.select([fd],[],[],0.2)
            if r: buf+=os.read(fd,4096)
            if b"OK" in buf or b"ERROR" in buf: break
        resp=buf.decode(errors="replace").strip().replace("\r\n","  ")
        if c=="ATE0" and "OK" not in resp:
            print(f"  info  {port}: no AT response"); break
        if c=="ATE0": print(f"  PASS  AT answered on {port}"); ok=True; continue
        print(f"        {c:<14} -> {resp or '(no response)'}")
    os.close(fd)
    if ok: break
sys.exit(0 if ok else 1)
PY
rc=$?
sudo -n systemctl start ModemManager
[ $rc -eq 0 ] || { fail "no port answered AT -> modem not talking (firmware/serial) even though USB enumerated"; exit 1; }

hr "4. ModemManager view (wait up to 30 s for it to probe)"
for i in $(seq 1 15); do mmcli -L 2>/dev/null | grep -q Modem && break; sleep 2; done
mmcli -L 2>&1
mmcli -m any 2>&1 | grep -iE "manufacturer|model|revision|state|power state|access tech|signal quality|registration|operator name|imei|sim|lock" | sed 's/^/    /'

hr "RESULT"
echo "  Board + modem enumerate and answer AT: hardware is alive."
echo "  SIM / registration lines above are informational (need SIM + antenna)."
exit 0
