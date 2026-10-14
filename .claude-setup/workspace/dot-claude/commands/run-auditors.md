---
name: run-auditors
description: Continue the /new-feature audit loop after the developer's direction check — runs audit rounds 2–3 (fresh auditor + adjudicator per round) against the current plan, reconciles deltas, refreshes summary.md. Hard cap 3 rounds total. Also the re-check path after developer corrections to an already-audited plan.
argument-hint: "[CIAS-NNNN or feature slug]  (omit in the planning session — it infers the workdir)"
when_to_use: After /new-feature stopped at round 1 with continuation recommended (status audited-round-1) and the developer confirmed the direction is right — or after developer corrections were applied to an audited plan.
---

# /run-auditors — audit-loop continuation (rounds 2–3)

`/new-feature` deliberately stops after **one** audit round so the developer can catch a conceptually-wrong plan before more agents run. This command runs the remaining rounds once the direction is confirmed. It reuses the new-feature pipeline verbatim: agent instructions at `.claude/skills/new-feature/prompts/auditor.md` / `adjudicator.md`, reconciliation and signal mechanics per `.claude/skills/new-feature/SKILL.md` (Steps 5 and 5.1). You orchestrate — you never audit, adjudicate, or edit source code yourself.

## Step 0 — Resolve & assess state

1. Workdir from `$ARGUMENTS` (`CIAS-NNNN` or slug → glob `.claude/jira-tasks/`). No argument: use this session's workdir if `/new-feature` just ran here; otherwise list plans with `status: audited-round-1` or `audited` and ask.
2. From `plan-and-estimate.md` (frontmatter + `## Revision log`) and the newest `adjudication*.md`, determine:
   - `last_round` — highest audit round on disk (plain filenames = round 1; `-rN` = round N),
   - that round's **signals** (`confirmed_high`, `delta_ratio` — from its Revision-log block / adjudication frontmatter),
   - `corrected` — whether any `Developer correction` Revision-log entries appear after the last round's block.
3. Gate — stop without spawning anything when:
   - `status: unstable-needs-rescope` → the plan needs re-scoping, not more auditing.
   - `status: draft-awaiting-audit` (or no adjudication on disk) → run `/new-feature` first.
   - No trigger fired in the last round AND not `corrected` → report "already converged — nothing to audit; next: `/create-phases <key>`".
   - `last_round == 3` → cap already reached; report the standing verdict.
4. Tell the developer in one line what will run and why (trigger signals, or "re-checking your corrections") before spawning.

## Step 1 — Run round(s)

Loop, starting at `N = last_round + 1`. Note today's date and pass it to every agent (fresh contexts).

1. Spawn a **fresh** `general-purpose` AUDITOR: instructions `.claude/skills/new-feature/prompts/auditor.md`, plus workdir, ticket key/slug, today's date, **round N**, output file `audit-report-r<N>.md`, and the note that the plan was revised since the last audit (Revision log records what changed — including developer corrections). Wait; confirm the file exists.
2. Spawn a **fresh** ADJUDICATOR: instructions `.claude/skills/new-feature/prompts/adjudicator.md`, same context, ruling on `audit-report-r<N>.md`, writing `adjudication-r<N>.md`. Wait; confirm the file exists.
3. **Reconcile** exactly per SKILL Step 5: apply CONFIRMED + PARTIALLY-CONFIRMED deltas to both estimate columns, update the plan frontmatter numbers, append a `Round <N>` block to the Revision log with the signals line.
4. Compute the round's signals (SKILL Step 5.1: `confirmed_high ≥ 3` OR `delta_ratio ≥ 30%`). Trigger fires AND `N < 3` → run round N+1. Otherwise exit the loop.

**Hard cap: 3 audit rounds total for a feature — never a fourth**, including rounds prompted by developer corrections. Each round's agents are fresh; files on disk are the only channel between them.

## Step 2 — Close out

1. Final status in `plan-and-estimate.md`: converged → `status: audited`; cap reached with a trigger still firing → `status: unstable-needs-rescope`.
2. **Refresh `<WORKDIR>/summary.md`** (SKILL Step 5.6 format, ≤ 45 lines): post-loop numbers, core decisions/assumptions updated for confirmed changes, "Needs your decision" and the audit line refreshed. The summary must never diverge from the plan.
3. Harvest any **new** entries in `pill-feedback.md` into `.claude/knowledge-pills/_inbox/` (SKILL Step 5.5 rules, including dedupe against existing drafts).

## Step 3 — Report

≤ 6 lines: rounds run this invocation and their confirmed/partial/false-positive counts · final estimates (both columns + speedup, before → after) · final status · any needs-human-decision items · next action — `/create-phases <key>`, or the re-scope conversation if unstable. Then the `Pills consulted:` line — the auditors' and adjudicators', from their reports (on top of the 6 lines).

## Hard rules

- Never run when already converged and uncorrected — report instead (agents cost real time; that's the whole reason this command exists as a separate step).
- Apply the adjudicator's verdicts mechanically; you are not an extra reviewer. Disagreements go to the user as notes.
- Never edit source/production code, `feature.md`, or any audit/adjudication artifact — you only reconcile the plan, refresh the summary, and harvest pill feedback.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
