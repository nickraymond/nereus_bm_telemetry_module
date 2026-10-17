#!/usr/bin/env bash
# link_down_test.sh - prove the LTE fallback: drop eth0 + wlan0 for N seconds, then restore.
#
# Purpose : controlled LTE-only window after provision_lte.sh, so you can check from
#           another tailnet machine that the Pi is still reachable (Tailscale over wwan0).
# Inputs  : $1 = window in seconds (default 120). Run ON the Pi as root, DETACHED, because
#           it cuts the LAN path your ssh session is probably using.
# Outputs : log on stdout: routes, egress interface, public IP, Tailscale state and
#           lifepo4wered power before / during / after; a tick every 20 s in the window.
# Assumes : NetworkManager manages eth0 + wlan0; NM profile `lte` is up (metric 700);
#           lifepo4wered-cli and vcgencmd present (Raspberry Pi + LiFePO4wered UPS).
# Example : sudo setsid nohup bash link_down_test.sh 120 > ~/link_down_test.log 2>&1 < /dev/null &
#           then from the Mac: tailscale ping <host>; ssh pi@<host> 'ip route; tail ~/link_down_test.log'
# Limits  : restores with `nmcli device connect` (3 tries for wlan0) and restarts
#           NetworkManager if wlan0 has no 192.168.x address afterwards; manual restore:
#           sudo nmcli device connect wlan0; sudo nmcli device connect eth0
#           Tested once on nereus000 2026-10-14 (docs/provisioning/nereus000_20261014.md).
set -u
N=${1:-120}
log(){ echo "[$(date +%T)] $*"; }
snap(){ ip route | grep default | sed 's/^/   route: /'; echo "   egress: $(ip route get 1.1.1.1 | head -1)"
  echo "   public ip: $(curl -s --max-time 10 https://api.ipify.org)   tailscale: $(tailscale ip -4 2>&1 | head -1) $(tailscale status --json 2>/dev/null | grep -m1 -o '"BackendState": *"[A-Za-z]*"')"
  echo "   power VIN=$(lifepo4wered-cli get VIN) VBAT=$(lifepo4wered-cli get VBAT) IOUT=$(lifepo4wered-cli get IOUT) throttled=$(vcgencmd get_throttled | cut -d= -f2)"; }
log "before"; snap
log "disconnect eth0 + wlan0 for ${N}s"; nmcli device disconnect eth0; nmcli device disconnect wlan0
sleep 10; log "links down (LTE only)"; snap
end=$((SECONDS + N)); while [ $SECONDS -lt $end ]; do sleep 20; log "tick: $(ip route get 1.1.1.1 | head -1 | awk '{print $5}') VIN=$(lifepo4wered-cli get VIN) IOUT=$(lifepo4wered-cli get IOUT)"; done
log "restore"; for i in 1 2 3; do nmcli device connect wlan0 && break; sleep 10; done; nmcli device connect eth0 || true
sleep 10; snap
ip -4 -br addr show wlan0 | grep -q 192.168 || { log "wlan0 not back -> restart NetworkManager"; systemctl restart NetworkManager; sleep 25; snap; }
log "wifi power management: $(/sbin/iwconfig wlan0 2>/dev/null | grep -o 'Power Management:[a-z]*')"; log "done"
