# nereus_bm_telemetry_module

Bristlemouth-powered cellular telemetry module. A pass-through Bristlemouth
node with a Raspberry Pi inside: the Pi talks to the mote over UART, subscribes
to topics from other nodes on the bus (a camera, for example) and forwards
their data to the nereus-vision backend over LTE. Commands flow the other way.

Hardware (current): Pi Zero 2W + USB hub + Sixfab Base HAT + Telit LE910C4-NF,
powered from the Bristlemouth bus. Bench/dev unit: nereus001 (Pi 5).

## Where things are

```
CLAUDE.md                 always-loaded router + engineering values
docs/SPEC.md              goal, verified facts, constraints, open questions
docs/TRACKER.md           rules + sprint ladder (the agent entry point)
docs/DESIGN.md            as-built architecture, decision log, bench results
docs/DEV_LOG.md           session log, newest first
docs/PROVISION_PI.md      fresh Pi -> working LTE uplink (tested 2026-10-08)
docs/reference/           verbatim prior art with provenance (nereus-deploy)
tools/provision_lte.sh    the whole LTE bring-up as one re-runnable script
tools/sixfab_board_check.sh  is the HAT + modem alive? USB -> tty -> AT -> MM
tools/lte_att_bringup.py  APN + AT&T operator lock on the modem (NVM)
```

## Quick start on a new Pi

```bash
scp tools/*.sh tools/*.py pi@<host>:~/
ssh pi@<host> 'sudo ./provision_lte.sh'
```

Pass = the script ends with `PASS: LTE uplink working` and a
`lte_provision_<UTC>.json` summary in the home directory. Full procedure and
what each step proves: `docs/PROVISION_PI.md`.
