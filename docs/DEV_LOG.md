# DEV_LOG.md — Session Log

*Newest entries on top. One entry per working session. Short: what changed,
what broke, what's next.*

---

## Entry template

```
## YYYY-MM-DD — Sprint Sn — <one-line summary>
**Branch:** sprint/n-slug
**Done:**  <bullets>
**Broke/surprised us:** <bullets or "nothing">
**Next:** <the single next bite>
```

---

## 2026-10-14 — S0b — LTE fallback + Tailscale on nereus000 (Zero 2W + hub), proven script unchanged

**Branch:** sprint/0b-nereus000-lte
**Done:**
- Moved the nereus001 HAT + modem (new AT&T IoT SIM …4825) to nereus000, the bm_cam_legacy bench Spotter-console host. `tools/provision_lte.sh` from main ran unchanged: PASS in 1 min 40 s, LTE at metric 700 behind Ethernet/Wi-Fi.
- Tailscale `nereus000` = 100.82.38.22. LTE-only test (eth0 + wlan0 down 120 s): reachable over the tailnet via the AT&T IP. New `tools/link_down_test.sh`.
- udev rule so ModemManager ignores the Spotter consoles (0483:5740), verified with both consoles plugged in (D6).
- Record with every change + restore command: `docs/provisioning/nereus000_20261014.md`.
- GPS (antenna on G): 3D fix, 9 sats, HDOP 0.7 via the proven mmcli location commands; TTFF not measured; left disabled.
**Broke/surprised us:**
- The Wi-Fi firmware crashed (`brcmf_fw_crashed`) at the end of the ModemManager apt install, and the Pi was off the network for ~15 min until a power cycle. Cause unknown; power was normal.
- `provision_lte.sh` step 4 (NetworkManager stopped) removes wlan0's IP for ~35 s. Run it detached; PROVISION_PI.md now says so.
- ModemManager 1.24 treats the Spotter consoles as modem candidates (`ID_MM_CANDIDATE=1`).
- The first Tailscale auth URL expired (~5 min, `http 410`) while Nick was clicking it.
- Lesson (Nick): run the proven script first, as-is; host-specific extras only after the modem works.
**Restore (nereus000):** `sudo nmcli connection delete lte; sudo systemctl disable --now ModemManager; sudo rm /etc/udev/rules.d/77-mm-ignore-spotter-consoles.rules && sudo udevadm control --reload; sudo tailscale logout` (backup: `~/lte_bringup_backup_20261014T160741Z/`).
**Next:** S0b on a freshly flashed field module, with a bench-supply current trace (Q1).

---

## 2026-10-08 — S0 — Sixfab HAT verified, LTE uplink live on nereus001, repo scaffolded

**Branch:** main (initial scaffold; first code sprint branches from here)
**Done:**
- Tested the suspect Sixfab Base HAT + Telit LE910C4-NF on nereus001: not damaged. USB, AT, SIM, RX/TX and data all pass (DESIGN §Bench).
- Found the real prior art: nickraymond/nereus-deploy `install.sh` + `manual_steps/lte_qmi.md`. Copied the doc verbatim to docs/reference with provenance.
- Ported/wrote `tools/sixfab_board_check.sh`, `tools/lte_att_bringup.py`, `tools/provision_lte.sh`; wrote docs/PROVISION_PI.md.
- Filled SPEC / TRACKER / DESIGN from today's measurements; proposed the S0b–S4 ladder.
**Broke/surprised us:**
- Forced AT&T selection fails with EMM cause 15 until the IoT APN is set on PDP context 1. The nereus-vision doc's order is required, not optional.
- The modem camps on a Verizon B13 cell while unregistered; the operator name "AT&T" in `#MONI` is misleading there. Trust `#RFSTS` PLMN.
- Shell quoting of AT scripts over ssh: put them in files, scp them, run them.
- nereus001 side effects: modemmanager, libqmi-utils, minicom, i2c-tools installed; ModemManager enabled; NM profile `lte` (autoconnect) added. Restore: `sudo nmcli connection delete lte; sudo systemctl disable --now ModemManager`.
**Next:** S0b — provision the Pi Zero 2W + hub with `tools/provision_lte.sh` (2026-10-09) and record the differences.
