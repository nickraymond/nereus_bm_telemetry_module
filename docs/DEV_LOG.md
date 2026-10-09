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
