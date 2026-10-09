# TRACKER.md — Sprint Ladder & Rules

*The agent entry point. Newest state lives here.*
*Last updated: {{DATE}} · Owner/gate: **{{OWNER}}***

---

## Rules for Agents (READ FIRST, EVERY SESSION)

1. **Read this whole document cover-to-cover first, every session.** Then skim
   `docs/SPEC.md` and `docs/DESIGN.md`. Read the top ~3 entries of
   `docs/DEV_LOG.md`.
2. **Take small code bites.** One TODO at a time, target ~300 LoC. If SPEC.md
   is too thin to inform the bite, stop and ask {{OWNER}}.
3. **Four nibbles per bite:**
   1. **Plan** — throwaway code ok; change no files. *Gate: {{OWNER}} approves.*
   2. **Code + unit tests** — flag {{OWNER}} on substantial plan changes.
   3. **Manual tests** — {{OWNER}} runs them; provide copy-pastable CLI.
   4. **Open PR.**
4. **Feature branch for all new work** — `sprint/<n>-<slug>`. Never commit to main.
5. **Every sprint ends with a live demo {{OWNER}} can run** — exact commands in
   the sprint's Demo section and the PR description.
6. **End of every session:** DEV_LOG.md entry (newest on top); DESIGN.md updated
   on any architecture/decision change.
7. **Facts carry sources; unknowns get flagged, not guessed.**
8. <Project-specific hard rules — safety, environments, secrets.>

### Project layout

```
docs/     SPEC.md TRACKER.md DESIGN.md DEV_LOG.md
<code dirs>
```

---

## Sprint ladder

State key: `[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked

### S0 — <name>  `[ ]`
**Goal:**
- [ ]
**Demo ({{OWNER}}):** <exact command → expected visible result>
**Needs:**

---

## Icebox (captured, not scheduled)

-
