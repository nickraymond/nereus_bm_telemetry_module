#!/usr/bin/env python3
"""lte_att_bringup.py - lock the Telit LE910C4-NF onto AT&T with the IoT APN.

Purpose : the manual AT checkpoint from nereus-deploy manual_steps/lte_qmi.md
          (docs/reference/nereus-deploy/lte_qmi.md step 4), scripted so a new
          Pi is one command. Order is the proven one: APN on PDP context 1 ->
          deregister -> force operator on LTE -> wait for CEREG 1 -> AT#REBOOT.
Inputs  : --port (default /dev/ttyUSB3; ttyUSB2 also answers AT but
          ModemManager owns it at runtime), --apn, --plmn, --wait-sec,
          --no-reboot, --status (read-only, no writes to the modem).
Outputs : one line per AT exchange on stdout; exit 0 only if the modem reports
          CEREG 1 or 5 before the reboot. Writes APN + manual operator lock to
          the modem's own NVM, so it survives Pi reboots and power cuts.
Assumes : ModemManager and NetworkManager are STOPPED by the caller (see
          tools/provision_lte.sh), and the caller restarts them afterwards.
          Run as root (the tty is root:dialout).
Example : sudo systemctl stop ModemManager NetworkManager
          sudo python3 tools/lte_att_bringup.py
          sudo systemctl start ModemManager NetworkManager
Limits  : AT&T only by default; another carrier needs its own APN + PLMN and
          may need a carrier firmware switch (AT#FWSWITCH; slot 0 = the AT&T
          image on the modem tested 2026-10-08, other slots unverified).
          Why the APN matters: with the firmware default "nxtgenphone" APN the
          AT&T IoT SIM is rejected with EMM cause 15 (measured 2026-10-08).
"""
import argparse, os, select, sys, termios, time

def open_port(port):
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    a = termios.tcgetattr(fd)
    a[0] = 0; a[1] = 0; a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL; a[3] = 0
    a[4] = a[5] = termios.B115200
    termios.tcsetattr(fd, termios.TCSANOW, a)
    return fd

def at(fd, cmd, timeout=3.0, show=True):
    os.write(fd, (cmd + "\r").encode())
    buf, t0 = b"", time.time()
    while time.time() - t0 < timeout:
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            buf += os.read(fd, 4096)
        if b"\r\nOK\r\n" in buf or b"ERROR" in buf:
            break
    txt = buf.decode(errors="replace").strip().replace("\r\n", "\n" + " " * 28)
    if show:
        print("%-26s -> %s" % (cmd, txt or "(no response)"), flush=True)
    return txt

def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--port", default="/dev/ttyUSB3")
    p.add_argument("--apn", default="iot0723.com.attz")
    p.add_argument("--plmn", default="310410", help="MCC+MNC, 310410 = AT&T")
    p.add_argument("--wait-sec", type=int, default=120)
    p.add_argument("--no-reboot", action="store_true", help="skip AT#REBOOT at the end")
    p.add_argument("--status", action="store_true", help="read-only report, change nothing")
    args = p.parse_args()

    if not os.path.exists(args.port):
        sys.exit(f"FAIL: {args.port} missing (modem not enumerated? run tools/sixfab_board_check.sh)")
    fd = open_port(args.port)
    if "OK" not in at(fd, "ATE0"):
        sys.exit(f"FAIL: no AT response on {args.port}")
    print(f"port={args.port} apn={args.apn} plmn={args.plmn} mode={'status' if args.status else 'bringup'}")

    at(fd, "AT+CPIN?")
    if args.status:
        for c in ("AT+CGDCONT?", "AT+COPS?", "AT+CEREG?", "AT+CGATT?", "AT+CSQ", "AT#RFSTS", "AT#CEERNET", "AT#FWSWITCH?", "AT#USBCFG?"):
            at(fd, c, 5)
        return 0

    at(fd, f'AT+CGDCONT=1,"IP","{args.apn}"')
    at(fd, "AT+CGDCONT?")
    at(fd, "AT+COPS=2", 30)                       # deregister first (nereus-deploy order)
    at(fd, f'AT+COPS=1,2,"{args.plmn}",7', 120)    # manual select, 7 = E-UTRAN
    registered = False
    for i in range(max(1, args.wait_sec // 10)):
        reg = at(fd, "AT+CEREG?", 3, show=False).split("\n")[0]
        att = at(fd, "AT+CGATT?", 3, show=False).split("\n")[0]
        csq = at(fd, "AT+CSQ", 3, show=False).split("\n")[0]
        print(f"t={(i + 1) * 10:3d}s  {reg}   {att}   {csq}", flush=True)
        if "+CEREG: 2,1" in reg or "+CEREG: 2,5" in reg or "+CEREG: 0,1" in reg or "+CEREG: 0,5" in reg:
            registered = True
            break
        time.sleep(10)
    at(fd, "AT+COPS?"); at(fd, "AT#RFSTS", 5); at(fd, "AT#CEERNET", 5)
    if not registered:
        print("FAIL: not registered. #CEERNET above is the network reject cause (15 = APN/subscription, see docs/DESIGN.md).")
        print("      Automatic selection restored so the modem keeps searching.")
        at(fd, "AT+COPS=0", 10)
        return 1
    print("PASS: registered on", args.plmn)
    if not args.no_reboot:
        at(fd, "AT#REBOOT", 5)
        print("modem rebooting: USB re-enumerates in ~20 s; then start ModemManager + NetworkManager")
    os.close(fd)
    return 0

if __name__ == "__main__":
    sys.exit(main())
