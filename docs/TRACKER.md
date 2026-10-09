# TRACKER.md — Sprint Ladder & Rules

*The agent entry point. Newest state lives here.*
*Last updated: 2026-10-08 · Owner/gate: **Nick Buemond***

---

## Rules for Agents (READ FIRST, EVERY SESSION)

1. **Read this whole document cover-to-cover first, every session.** Then skim
   `docs/SPEC.md` and `docs/DESIGN.md`. Read the top ~3 entries of
   `docs/DEV_LOG.md`.
2. **Take small code bites.** One TODO at a time, target ~300 LoC. If SPEC.md
   is too thin to inform the bite, stop and ask Nick.
3. **Four nibbles per bite:**
   1. **Plan** — throwaway code ok; change no files. *Gate: Nick approves.*
   2. **Code + unit tests** — flag Nick on substantial plan changes.
   3. **Manual tests** — Nick runs them; provide copy-pastable CLI.
   4. **Open PR.**
4. **Feature branch for all new work** — `sprint/<n>-<slug>`. Never commit to main.
5. **Every sprint ends with a live demo Nick can run** — exact commands in
   the sprint's Demo section and the PR description.
6. **End of every session:** DEV_LOG.md entry (newest on top); DESIGN.md updated
   on any architecture/decision change.
7. **Facts carry sources; unknowns get flagged, not guessed.**
8. **Hardware rules:** bench units only (SPEC §Safety); stop ModemManager
   before raw AT and restart it after; never run the modem without the M
   antenna; back up any file on a Pi before editing it and leave the restore
   command in the DEV_LOG.

### Project layout

```
tools/                 scripts that run on the Pi (provision, check, bring-up)
docs/reference/        verbatim prior art + provenance
docs/PROVISION_PI.md   the tested fresh-Pi workflow
```

---

## Sprint ladder

| Sprint | Outcome | Demo (Nick runs it) | Status |
|---|---|---|---|
| S0 | LTE bring-up captured as a script; HAT verified | `sudo ./provision_lte.sh` on nereus001 ends PASS | DONE 2026-10-08 on nereus001 |
| S0b | Same on the Pi Zero 2W + hub (field target) | fresh flash → quick start in README → PASS + JSON summary | NEXT (2026-10-09) |
| S1 | Uplink: send one file (image, then 30 s clip) from the Pi to staging over wwan0; log bytes, seconds, kbps, and modem signal per upload | upload a clip from the Pi; it shows on the dashboard; a CSV row per upload | queued |
| S2 | Bus side: Pi ↔ mote UART, subscribe to a camera topic, reassemble a clip received over the bus (reuse bm_cam_legacy BM_Devel_Pi bm_serial / frame decoder) | bmcam003 publishes a clip; the module writes it to disk intact (hash match) | queued |
| S3 | Downlink: poll the backend's command queue over LTE and forward a command onto the bus; ack back | dashboard command → camera node acts → ack on dashboard | queued |
| S4 | Pool demo | dashboard command → 30 s clip from the pool camera → dashboard, via this module | queued |
| S5+ | Power cycling + optional halt (Q1/Q2); OTA for module and camera (Q6); bounded live video | TBD after S4 | future |

Ladder S0b–S4 approved by Nick 2026-10-08.

## Current sprint: S0b — Pi Zero 2W provisioning

**TODO (one at a time)**
- [ ] Flash Pi Zero 2W (record OS/kernel in DESIGN §Bench), Wi-Fi + Tailscale
      (bm_cam_legacy skill `pi-tailscale-setup`), passwordless sudo.
- [ ] Stack hub + HAT, SIM in, antenna on M. Plug HAT USB into the hub.
- [ ] `scp tools/* pi@<host>:~/ && ssh pi@<host> 'sudo ./provision_lte.sh'`.
- [ ] Record differences from nereus001 (USB hub enumeration, power draw
      symptoms, kernel/ModemManager versions) in DESIGN §Bench results.
- [ ] Answer Q5 in SPEC. Q1: power the Zero from Nick's bench supply with a current readout and record idle / registered / transmit peaks during step 7.

**Demo:** the quick start in README on the Zero ends `PASS: LTE uplink working`.
