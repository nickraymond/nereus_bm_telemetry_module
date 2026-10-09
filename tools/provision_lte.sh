#!/usr/bin/env bash
# provision_lte.sh - fresh Pi -> working LTE uplink on the Sixfab Base HAT + Telit LE910C4-NF.
#
# Purpose : the whole workflow that was done by hand on nereus001 on 2026-10-08,
#           in order, as one re-runnable script. Each step prints what it does
#           and stops at the first real failure with the layer that failed.
# Inputs  : env APN (default iot0723.com.attz), PLMN (default 310410 = AT&T),
#           PROBE_URL (default the nereus-vision staging root). Run ON the Pi.
# Outputs : stdout log; /home/<user>/lte_provision_<UTC>.json summary with the
#           identifiers and the data-path result. Exit 0 only if curl over
#           wwan0 succeeds.
# Assumes : Raspberry Pi OS (Bookworm or Trixie) with NetworkManager, internet
#           over Wi-Fi/eth for apt, passwordless sudo, HAT on USB with SIM +
#           LTE antenna on M. Modem may be plugged in before or after step 1.
# Example : scp tools/*.sh tools/*.py pi@nereus002:~/ && ssh pi@nereus002 'sudo APN=iot0723.com.attz ./provision_lte.sh'
# Limits  : AT&T IoT SIM path only (see lte_att_bringup.py). Does not touch
#           Wi-Fi, Tailscale, cron, or power/halt behaviour. Default route via
#           wwan0 gets metric 700, i.e. below Wi-Fi (600): LTE is a fallback
#           uplink until a sprint decides otherwise (SPEC.md open question Q3).
set -u
APN="${APN:-iot0723.com.attz}"; PLMN="${PLMN:-310410}"; PROBE_URL="${PROBE_URL:-https://nereus-vision-staging.onrender.com/}"
HERE="$(cd "$(dirname "$0")" && pwd)"; TS="$(date -u +%Y%m%dT%H%M%SZ)"
# summary goes to the invoking user's home even under sudo
RUNUSER="${SUDO_USER:-$USER}"; OUTDIR="$(getent passwd "$RUNUSER" | cut -d: -f6)"; OUT="${OUTDIR:-$HOME}/lte_provision_${TS}.json"
log(){ echo "[$(date +%H:%M:%S)] $*"; }; die(){ echo "FAIL: $*" >&2; exit 1; }
S(){ sed "s/\x1b\[[0-9;]*m//g"; }
log "provision_lte start host=$(hostname) apn=$APN plmn=$PLMN out=$OUT"

log "step 1/7: packages"
sudo -n apt-get install -y -q modemmanager libqmi-utils minicom usbutils >/dev/null || die "apt install failed (no internet over wifi/eth?)"
sudo -n systemctl enable --now ModemManager >/dev/null 2>&1
log "  mmcli $(mmcli --version | head -1 | awk '{print $NF}')  qmicli $(qmicli --version | head -1 | awk '{print $NF}')"

log "step 2/7: wait for the modem on USB (plug it in now if you have not)"
for i in $(seq 1 60); do lsusb | grep -qiE "telit|1bc7:" && break; sleep 2; done
lsusb | grep -qiE "telit|1bc7:" || die "modem never enumerated: HAT power, USB data cable, or modem"
log "  $(lsusb | grep -iE 'telit|1bc7:')"

log "step 3/7: board check ladder (USB -> tty -> AT -> ModemManager)"
bash "$HERE/sixfab_board_check.sh" || die "board check failed, see above"

log "step 4/7: AT&T APN + operator lock (modem NVM), then modem reboot"
sudo -n nmcli connection down lte >/dev/null 2>&1 || true
sudo -n systemctl stop ModemManager NetworkManager; sleep 1
sudo -n python3 "$HERE/lte_att_bringup.py" --apn "$APN" --plmn "$PLMN"; rc=$?
sudo -n systemctl start NetworkManager
[ $rc -eq 0 ] || { sudo -n systemctl start ModemManager; die "registration failed (SIM activated? antenna on M?)"; }
log "  waiting for USB re-enumeration after AT#REBOOT"
sleep 8; for i in $(seq 1 30); do [ -e /dev/cdc-wdm0 ] && [ -e /dev/ttyUSB3 ] && break; sleep 2; done
[ -e /dev/cdc-wdm0 ] || die "modem did not come back after reboot"
sudo -n systemctl start ModemManager

log "step 5/7: wait for ModemManager state connected/registered (up to 90 s)"
for i in $(seq 1 18); do st=$(mmcli -m any 2>/dev/null | S | grep -oE "state: *[a-z-]+" | head -1); echo "  t=$((i*5))s $st"; echo "$st" | grep -qE "registered|connected" && break; sleep 5; done
mmcli -m any 2>&1 | S | grep -iE "operator (id|name)|registration|packet service|initial bearer apn" | sed 's/^/  /'

log "step 6/7: NetworkManager profile 'lte' (nereus-deploy lte_qmi.md step 6)"
nmcli -t connection show | grep -q "^lte:" || sudo -n nmcli connection add type gsm ifname cdc-wdm0 con-name lte apn "$APN" >/dev/null
sudo -n nmcli connection modify lte gsm.apn "$APN" gsm.network-id "$PLMN" ipv4.method auto ipv6.method ignore connection.autoconnect yes
sudo -n nmcli connection up lte 2>&1 | tail -1 | sed 's/^/  /'; sleep 5
ip -4 -br addr show wwan0 | sed 's/^/  /'; ip route | grep wwan0 | sed 's/^/  /'

log "step 7/7: data path over wwan0 only"
PING=$(ping -I wwan0 -c 4 -W 4 1.1.1.1 2>&1 | grep -oE "[0-9]+ received" | awk '{print $1}'); PING=${PING:-0}
HTTP=$(curl --interface wwan0 -s -o /dev/null --max-time 20 -w "%{http_code}" "$PROBE_URL" 2>/dev/null); HTTP=${HTTP:-000}
PUBIP=$(curl --interface wwan0 -s --max-time 15 https://api.ipify.org 2>/dev/null)
log "  ping 1.1.1.1: $PING/4   curl $PROBE_URL: HTTP $HTTP   public ip: ${PUBIP:-none}"

KV=$(sudo -n mmcli -m any --output-keyvalue 2>/dev/null)
# mmcli keyvalue lines are 'key<spaces>: value'; split on the FIRST colon only (values may contain ':')
g(){ printf '%s\n' "$KV" | awk -v k="$1" 'index($0,k" ")==1 {sub(/^[^:]*: */,""); print; exit}'; }
SIMP=$(g modem.generic.sim); SKV=$(sudo -n mmcli -i "${SIMP:-0}" --output-keyvalue 2>/dev/null)
sg(){ printf '%s\n' "$SKV" | awk -v k="$1" 'index($0,k" ")==1 {sub(/^[^:]*: */,""); print; exit}'; }
cat > "$OUT" <<JSON
{"host":"$(hostname)","utc":"$TS","modem":"$(g modem.generic.model)","firmware":"$(g modem.generic.revision)","imei":"$(g modem.generic.equipment-identifier)",
 "iccid":"$(sg sim.properties.iccid)","imsi":"$(sg sim.properties.imsi)","operator_id":"$(g modem.3gpp.operator-code)","operator_name":"$(g modem.3gpp.operator-name)",
 "registration":"$(g modem.3gpp.registration-state)","signal_pct":"$(g modem.generic.signal-quality.value)","apn":"$APN","plmn":"$PLMN",
 "wwan0_ip":"$(ip -4 -o addr show wwan0 2>/dev/null | awk '{print $4}')","ping_ok":"$PING/4","http_code":"$HTTP","public_ip":"$PUBIP"}
JSON
chown "$RUNUSER" "$OUT" 2>/dev/null; log "summary written: $OUT"; cat "$OUT"
[ "$HTTP" = "200" ] && { log "PASS: LTE uplink working"; exit 0; } || die "data path not working (HTTP $HTTP, ping $PING/4)"
