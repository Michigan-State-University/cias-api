---
name: create-phases
description: Confirm an audited /new-feature plan with the developer, then turn plan-and-estimate.md into ordered, PR-sized implementation phases (phases.md index + one file per phase) that fresh implementation sessions can execute one at a time.
argument-hint: "[CIAS-NNNN or feature slug]  (omit in the planning session — it infers the workdir)"
when_to_use: After a /new-feature run, once the developer has reviewed summary.md and is ready to confirm the plan and start implementation. Works in the planning session or any later session.
---

# /create-phases — confirmed plan → implementation phases

Bridges planning and implementation: takes the **audited** plan produced by `/new-feature`, runs the human confirmation gate, and emits phases sized for one PR / one focused implementation session each. You transform and gate here — you do **not** re-plan, re-estimate, or write production code.

Status flow across the artifacts: `draft-awaiting-audit → audited-round-1 (→ /run-auditors) → audited → confirmed → phased` (dead end: `unstable-needs-rescope`; `audited-round-1` is skipped when round 1 converges on its own).

## Phase 0 — Resolve the workdir

1. From `$ARGUMENTS`: a `CIAS-NNNN` key or slug → glob `.claude/jira-tasks/` for the matching `cias-<NNNN>-*` / `feature-<slug>` dir.
2. No argument: if this session just ran `/new-feature`, use that workdir. Otherwise glob `.claude/jira-tasks/*/plan-and-estimate.md` for plans with `status: audited` or `confirmed`, and ask the user which one.
3. Call it `<WORKDIR>`. Required inputs: `<WORKDIR>/plan-and-estimate.md` + `<WORKDIR>/summary.md`. Missing → stop and say the plan isn't ready (point at `/new-feature`).

## Phase 1 — Confirmation gate (the human is the gate)

1. Check plan frontmatter `status`:
   - `unstable-needs-rescope` → **stop.** The gate exists to keep unstable plans out of implementation; tell the user to re-scope via `/new-feature`.
   - `draft-awaiting-audit` → stop; the audit loop hasn't run.
   - `audited-round-1` → audit continuation was recommended and hasn't run: tell the user to run `/run-auditors <key>` first. Only proceed if they explicitly say to phase it anyway — then record `Developer override — <date>: phased at audited-round-1, rounds 2–3 skipped` in the plan's Revision log.
   - `confirmed` / `phased` → gate already passed; skip to Phase 2 (for `phased`, confirm the user wants phases regenerated — see Re-runs below).
2. Show the developer `summary.md`'s **Core decisions** and **Load-bearing assumptions** checkboxes plus any **Needs your decision** items, then ask (AskUserQuestion): **Confirm plan** / **I have corrections**.
3. **Corrections path**: take the corrections, apply them to `plan-and-estimate.md` AND `summary.md` (keep them consistent — the summary must never diverge from the plan). Adjust affected line-item estimates proportionally and note each change under `## Revision log` as `Developer correction — <date>: <what>`. If a correction invalidates a core decision or moves the estimate by ≥ 30%, say plainly that the plan should go back through the audit loop (`/new-feature` re-run) rather than be phased on a hand-edited foundation — let the developer decide.
4. Open **Needs your decision** items must be answered here — phases cannot be built on an unanswered scope question. Record answers in `feature.md` under `## Clarifications` and fold them into the plan.
5. On confirm: set `status: confirmed` + `confirmed: <YYYY-MM-DD>` in both `plan-and-estimate.md` and `summary.md` frontmatter.

## Phase 2 — Generate the phases

Derive phases from the plan's **Build order** and **Work breakdown**. Rules:

- **PR-sized**: each phase is an independently reviewable increment targeting one `feature/*` branch merge into `dev` — roughly ≤ 2–3 AI-assisted days. Typical shape for a full-stack feature: ① data & contract (migration, models, serializer, routes) → ② backend behavior (services, abilities, jobs, integrations) → ③ frontend (Redux module, containers, forms, i18n) → ④ integration hardening + QA prep. Split or merge to fit the actual plan — the typical shape is not a quota.
- **Dependency-honest**: a phase may only depend on earlier phases. Respect the plan's blockers (migration → serializer → saga).
- **Tests travel with their phase** — backend specs in the backend phase, frontend tests in the frontend phase. Never a trailing "write all tests" phase. Manual/QA lands in the final phase as a checklist.
- **Coverage is total**: every work-breakdown line item maps to exactly one phase — no orphans, no duplicates. Sum of phase estimates must reconcile with the plan's roll-up (state where review/contingency sits — spread per phase or noted separately).
- **Self-contained files**: each phase file must let a *fresh* implementation session work without reading the whole plan — restate the item's what/where (verified paths from the plan), don't just reference numbers.

Write:

`<WORKDIR>/phases.md` — the index:
```markdown
---
key: <CIAS-NNNN or omit>
phased: <YYYY-MM-DD>
phases_total: <n>
status: in-progress
---
# <CIAS-NNNN> — Implementation phases

| # | Phase | Repo(s) | Est (trad / ai) | Depends on | Status |
|---|-------|---------|-----------------|------------|--------|
| 1 | <name> | cias-api | 2d / 1d | — | pending |

**How to use**: run `/implement-phase <CIAS-NNNN> <N>` (no number = next runnable phase), ideally in a fresh session — it reads `phases/phase-<N>-*.md`, does the work, and flips the phase status (pending → in-progress → done) here and in the phase file.
<one line: estimates reconcile with plan-and-estimate.md — where contingency/review sits>
```

`<WORKDIR>/phases/phase-<N>-<kebab-name>.md` — one per phase:
```markdown
---
phase: <N>
name: <name>
status: pending          # pending | in-progress | done
repos: [cias-api]
estimate_traditional: <d>
estimate_ai_assisted: <d>
depends_on: [<phase numbers, or none>]
---
# Phase <N> — <name>

## Goal
<1–2 sentences: what exists and works when this phase is done>

## Work items
<each: what · where (verified path or "new at …") · notes — carried from the plan>

## Tests (part of this phase)
<the specs/Jest tests this phase must add>

## Acceptance criteria
<checkable statements — "migration runs + rolls back", "endpoint returns JSON:API <resource> for role X", "lint + tests green">

## Out of scope
<adjacent things explicitly deferred to later phases>
```

## Phase 2.5 — Sanity audit (one fresh agent; transformation check, not a re-plan)

The plan's content was already adversarially audited by `/new-feature` — do **not** re-audit scope or estimates here. This pass verifies the plan → phases **transformation**. Spawn one fresh `general-purpose` agent:

> You are the PHASE AUDITOR. Working directory: `<WORKDIR>` (relative to the workspace root, your cwd).
> Read `plan-and-estimate.md`, `phases.md`, and every `phases/phase-*.md`. Verify the invariants below
> against those files and — for touchpoint paths — the actual code (Read/Grep/Glob in `cias-api/`, `cias-web/`).
> Write `<WORKDIR>/phases-audit.md`: each invariant as PASS or FAIL with evidence, then a findings list.
> Do not edit any other file. Return a ≤4-line summary plus a `Pills consulted:` line.
>
> Invariants:
> 1. **Coverage** — every work-breakdown line item of the plan maps to exactly one phase; no orphans, no duplicates, no scope invented by the phases.
> 2. **Reconciliation** — per-column sums of phase estimates match the plan's roll-up (contingency/review placement stated).
> 3. **Dependencies** — every `depends_on` points to an earlier phase only; the plan's build-order blockers (e.g. migration → serializer → saga) are respected.
> 4. **Self-containment** — each phase file is executable without the plan: work items restate what/where; spot-check that stated paths exist (or are marked "new at …").
> 5. **Tests placement** — tests sit inside the phase they belong to; no trailing all-tests phase; manual/QA checklist is in the final phase.
> 6. **PR-size** — no phase exceeds ~3 AI-assisted days; none is trivially small (< ~0.5d) without a stated reason.
> 7. **Acceptance criteria** — every phase's criteria are objectively checkable.

Then **you** fix every FAIL directly (you authored the phases — these are mechanical corrections), record them in `phases-audit.md` under `## Fixes applied`, and re-verify the affected invariants yourself. **One audit round only** — if a FAIL can't be fixed mechanically (e.g. coverage exposes a genuine scope question), take it to the developer instead of guessing.

## Phase 3 — Report

1. Set `status: phased` in `plan-and-estimate.md` frontmatter (keep `confirmed:` date).
2. Report: phase table, the reconciliation line (phase sums vs plan totals), the sanity-audit outcome in one line (`7/7 invariants PASS` or `<n> FAILs fixed — see phases-audit.md`, plus anything deferred to the developer), and the next action — `/implement-phase <CIAS-NNNN> 1` in a fresh session. End with the `Pills consulted:` line (yours and the phase auditor's).

## Re-runs & edits

- Regenerating when phases already exist: warn, and **preserve status** of phases already `in-progress`/`done` — restructure only `pending` ones unless the user explicitly says otherwise.
- Mid-implementation scope changes are edits to the affected phase file(s) + index row — not a full regeneration.

## Hard rules

- Never phase an unconfirmed plan — the gate is the point of this command.
- Never skip the Phase 2.5 sanity audit, and never report phases as ready while a FAIL is unfixed and undisclosed.
- No re-estimating and no new scope: phases reshuffle the confirmed plan; they don't grow it. New work discovered later goes through the plan (revision log) first.
- Phase files restate what they need — an implementation session must not need session-1 context.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
