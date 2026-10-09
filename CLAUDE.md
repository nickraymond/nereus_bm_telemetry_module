# CLAUDE.md — nereus_bm_telemetry_module

## Start here, every session

This repo runs on the agent discipline in **docs/TRACKER.md**. Before any other
work: run **/agent-entry** (or follow the Rules for Agents at the top of
docs/TRACKER.md). Owner and approval gate: **Nick Buemond**.

Docs map — read per the ritual, don't skip it:

- `docs/SPEC.md` — goal; verified facts; hard constraints; open questions
- `docs/TRACKER.md` — rules + sprint ladder (the entry point)
- `docs/DESIGN.md` — as-built architecture + decision log
- `docs/DEV_LOG.md` — session log, newest first
- `docs/PROMPTS.md` — Nick's kickoff prompts
- `docs/PROVISION_PI.md` — fresh Pi to working LTE uplink, the tested workflow

Layout: `tools/` (provisioning + modem scripts, run on the Pi) ·
`docs/reference/` (verbatim copies of prior art, with provenance).

## Engineering values (apply to every bite)

1. **Boring, debuggable engineering.** Small modules, explicit control flow,
   visible logs, plain formats. Build for the current sprint, not an imagined
   future.
2. **Reuse before rewriting.** Inspect prior art first; adapt the smallest
   working piece; document what was reused. A rewrite needs a measurable reason.
   Prior art for this repo: nickraymond/nereus-deploy (LTE bring-up),
   bm_cam_legacy `BM_Devel_Pi/` (mote UART, command daemon, chunked transmit),
   nereus-vision-dev `device/system_agent/` (mmcli telemetry, backend client).
3. **Never invent facts.** APIs, formats, limits, pinouts: verify against
   primary sources or measure, else flag in SPEC.md §Open questions.
4. **Trust artifacts, not exit codes.** Verify outputs exist, sizes are
   plausible, and content is usable before calling anything done.
5. **One variable at a time.** Record the known-good path before changing it.
6. **Fail loudly and usefully.** Errors carry context and a recovery hint;
   partial failure never destroys good data.
7. **Field runtime constraints.** Pi Zero 2W (512 MB, one USB data port via a
   hub); power comes from the Bristlemouth bus and is cut without warning, so
   nothing may depend on a clean shutdown; cellular data costs money and
   energy, so every transmit is sized and logged. Modem AT ports: ModemManager
   owns ttyUSB2 at runtime; stop it before raw AT, restart it after.
8. **Hard constraints in SPEC.md are absolute.**

> Never trust a script just because it exits successfully. Trust the artifacts.
