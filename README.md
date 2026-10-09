# Agent Process Template

Sofar-style agent discipline, parameterized. This folder mirrors a real repo's
layout exactly — starting a new project is copy-and-fill.

```
SPEC.md      ─┐  what OWNER wants      ┌─ DESIGN.md    ─┐
TRACKER.md   ─┴──► code generation ────┤                ├─ what it did
                        │              └─ DEV_LOG.md   ─┘
                        ▼
                    the thing
```

## Contents (mirrors repo root)

```
CLAUDE.md                      always-loaded router + engineering values
.claude/skills/agent-entry/    session-start ritual  → /agent-entry
.claude/skills/capture-task/   tracker capture       → /capture-task
docs/SPEC.md                   goal, verified facts, constraints, open questions
docs/TRACKER.md                rules + sprint ladder (the agent entry point)
docs/DESIGN.md                 as-built architecture + decision log
docs/DEV_LOG.md                session log, newest first
docs/PROMPTS.md                owner's kickoff prompts (verbatim, fill <N>/<slug>)
```

## Starting a new project

1. Copy everything in this folder into the new repo root (including the hidden
   `.claude/` directory — check it survived the copy).
2. Find-and-replace across all files: `{{OWNER}}` → your name,
   `{{PROJECT}}` → project name, `{{DATE}}` → today.
3. Fill `docs/SPEC.md` (goal, verified facts, non-goals) and the TRACKER.md
   sprint ladder. DESIGN.md / DEV_LOG.md start near-empty — agents fill them.
4. Add project code dirs; update the layout lines in CLAUDE.md and TRACKER.md.
5. First session: paste the "New sprint" prompt from docs/PROMPTS.md.

## Division of labor (why each file exists)

- **CLAUDE.md** — loaded every session, kept short: points at the ritual,
  carries only timeless engineering values. One home per rule; no duplicates.
- **Skills** — procedures, loaded on demand. Repo-local so the repo controls
  them. Do NOT copy these into `~/.claude/skills/` — a same-named personal
  skill silently overrides every repo's version.
- **docs/** — all project state. Prompts stay constant; requirements go in
  SPEC/TRACKER, never in chat.

## The rules (summary — full text in docs/TRACKER.md)

- TRACKER cover-to-cover every session; skim SPEC + DESIGN; top 3 DEV_LOG entries
- Bites ~300 LoC, one TODO at a time
- Four nibbles: plan (OWNER gate) → code+tests → manual tests (OWNER runs,
  copy-pastable CLI) → PR
- Feature branch for ALL new work (`sprint/<n>-<slug>`); never commit to main
- Every sprint ends with a live demo OWNER can run
- DEV_LOG entry every session; DESIGN updated on any decision
- Facts carry sources; unknowns get flagged, not guessed
