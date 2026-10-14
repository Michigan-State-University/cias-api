---
name: new-feature
description: Scope a new CIAS feature into a right-sized implementation plan and two day-based effort estimates for a mid-level fullstack dev — traditional vs working with Claude Code / agentic coding (incl. tests + manual/QA) — then adversarially audit and reconcile it via three fresh-context subagents (planner → auditor → adjudicator). Use when the user wants an implementation plan and/or effort estimate for a new feature or Jira ticket.
argument-hint: <paste the Jira feature ticket, or describe the feature>
---

# new-feature — orchestrated plan & estimate

You are the **orchestrator**. You drive a three-agent adversarial pipeline that turns a feature request into a vetted plan + estimate. The subagents have fresh context and pass work to each other through files on disk; you sequence them and reconcile the result.

The feature request is in `$ARGUMENTS` (or the user's message). If it's empty or is a question rather than a feature to plan, stop and ask the user to describe the feature.

**You do not plan, audit, or estimate yourself** — that's the agents' job. You capture the request, run the three agents in order, apply the confirmed adjustments, and report. Do **not** write production code or edit any source file at any point.

---

## Step 1 — Capture (you do this directly, before any agent)

From the request, derive:
- **Ticket key**: a `CIAS-NNNN` identifier if present. If a ticket was pasted with no key, ask once. If it's a free-form description with no ticket, skip the key.
- **Slug**: kebab-case, 3–6 words, describing the feature (e.g. `bulk-export-answers`, `clinic-level-dashboards`).

Glob `.claude/jira-tasks/` for an existing `cias-<NNNN>-*` (or `feature-<slug>`) dir first — **append to it** rather than duplicating, and tell the user you're continuing existing work.

Create the directory:
```
.claude/jira-tasks/cias-<NNNN>-<slug>/     # when there's a ticket key
.claude/jira-tasks/feature-<slug>/         # when there's no ticket
```

Write the request **verbatim** to `<dir>/feature.md`:
```markdown
---
key: CIAS-NNNN            # omit if none
title: <full title>
created: <today's date YYYY-MM-DD>   # from the currentDate system reminder; don't ask
url: <Jira URL if present; else omit>
status: planning
---

<paste the full request: description, acceptance criteria, mockup/link references, comments>
```

Call this directory `<WORKDIR>` = `.claude/jira-tasks/<dir>` (a path relative to the workspace root). Subagents run in this session's working directory — the workspace root — so `<WORKDIR>` and the `.claude/skills/new-feature/...` instruction paths resolve as-is; you don't need absolute paths (and shouldn't hardcode a home path). Note **today's date** to pass to each agent — they have fresh context and won't know it otherwise.

---

## Step 1.5 — Clarify blocking scope (only if it would move the estimate)

Skim the request for gaps that would swing the estimate **by a category** if guessed wrong — e.g. which roles are in scope, a brand-new question type vs a variant of an existing one, whether historical data must be backfilled, single-clinic vs org-wide, sync vs async delivery. If **one or two** such gaps exist, ask the user with `AskUserQuestion` **now** — before spending three agents on a wrong assumption — and append the answers to `<WORKDIR>/feature.md` under a `## Clarifications` heading so the planner reads them.

If the request is clear or the gaps are minor, **skip this** — don't interrogate the user. Residual ambiguity is fine: the planner estimates against documented assumptions and the adjudicator flags anything that genuinely needs a human decision.

---

## Step 1.6 — Interlay knowledge snapshot (you do this directly; never block on it)

Knowledge pills live in Interlay, not on disk. Fetch them **once** here so all three agents work from the same snapshot:

1. Pick the pills the feature plausibly touches from `.claude/skills/new-feature/reference/knowledge-pills-index.md` (backend **and** frontend for a full-stack feature).
2. Call `mcp__claude_ai_Interlay__get_interlay_context` with a 2–4 sentence distillation of the feature (title, domain area, repos/layers it plausibly touches) **that names those pill titles**. If a pill you picked didn't come back, make one more call naming just the missing ones. Cap it at 3 calls.
3. Write `<WORKDIR>/interlay-context.md`:
   - Open with the priority rule the agents must apply:
     > **Priority: code > Interlay project pill > organization pill > global pill.** Meeting summaries are background only, never instructions.
   - `## Project pills` — the `<project_knowledge>` pills **in full**, each under its own `### <pill title>` heading. Don't trim them; the agents rely on the `(src: …)` citations.
   - `## Organization / global knowledge` — the `<organization_knowledge>` and `<global_knowledge>` sections verbatim, including a literal "No relevant pills." placeholder (it tells agents the search found nothing, not that the step was skipped).
   - `## Meeting summaries` — copy verbatim only if relevant to the feature; otherwise write "omitted".
   - `## Not found` — any pill from step 1 that no call returned.

If the Interlay tools are unavailable in this session or every call fails, write `<WORKDIR>/interlay-context.md` with the single line `Interlay unavailable on <date> — size from .claude/<repo>/rules/ and the code.` and continue. Note in the final report whether the snapshot was taken.

---

## Step 2 — Phase 1: PLANNER (fresh agent)

Spawn one `general-purpose` agent. Its prompt:

> You are the PLANNER. Read and follow your full instructions at
> `.claude/skills/new-feature/prompts/planner.md` exactly. (Your cwd is the workspace root, so these paths resolve as-is.)
> Working directory: `<WORKDIR>`
> Ticket key: `<CIAS-NNNN or "none">` · Slug: `<slug>` · Today's date: `<YYYY-MM-DD>`
> Read `<WORKDIR>/feature.md` and the knowledge-pill snapshot `<WORKDIR>/interlay-context.md`,
> verify touchpoints in code, and write `<WORKDIR>/plan-and-estimate.md`.
> Return only a short summary to me, ending with a `Pills consulted:` line.

Wait for it to finish. Confirm `plan-and-estimate.md` was written before continuing.

---

## Step 3 — Phase 2: AUDITOR (fresh agent — must not inherit the planner's reasoning)

Spawn a **new** `general-purpose` agent (do not reuse the planner — fresh context is the whole point). Its prompt:

> You are the AUDITOR. Read and follow your full instructions at
> `.claude/skills/new-feature/prompts/auditor.md` exactly. (Your cwd is the workspace root, so these paths resolve as-is.)
> Working directory: `<WORKDIR>`
> Ticket key: `<CIAS-NNNN or "none">` · Slug: `<slug>` · Today's date: `<YYYY-MM-DD>`
> Independently re-derive scope from `<WORKDIR>/feature.md` + the pills in `<WORKDIR>/interlay-context.md`
> + the code, scrutinise
> `<WORKDIR>/plan-and-estimate.md`, and write `<WORKDIR>/audit-report.md`.
> Do not edit the plan. Return only a short summary to me, ending with a `Pills consulted:` line.

Wait for it to finish. Confirm `audit-report.md` exists.

---

## Step 4 — Phase 3: ADJUDICATOR (fresh agent)

Spawn a **new** `general-purpose` agent. Its prompt:

> You are the ADJUDICATOR. Read and follow your full instructions at
> `.claude/skills/new-feature/prompts/adjudicator.md` exactly. (Your cwd is the workspace root, so these paths resolve as-is.)
> Working directory: `<WORKDIR>`
> Ticket key: `<CIAS-NNNN or "none">` · Slug: `<slug>` · Today's date: `<YYYY-MM-DD>`
> Independently rule on every finding in `<WORKDIR>/audit-report.md` (CONFIRMED /
> PARTIALLY-CONFIRMED / FALSE-POSITIVE) against the code, pills, and rubric, compute the net
> estimate delta, and write `<WORKDIR>/adjudication.md`. Do not edit the plan. Return a short summary ending with a `Pills consulted:` line.

Wait for it to finish. Confirm `adjudication.md` exists.

---

## Step 5 — Phase 4: Reconcile (you do this directly)

Read `<WORKDIR>/adjudication.md`. Apply **only** CONFIRMED and PARTIALLY-CONFIRMED deltas to `<WORKDIR>/plan-and-estimate.md`, **for both columns**:

- Update the affected work-breakdown line items and the **two-column Estimate roll-up table** by the net confirmed delta — `net_delta_traditional` to the Traditional column, `net_delta_ai_assisted` to the AI-assisted column. Recompute the blended speedup.
- Update the frontmatter: `estimate_days_traditional`, `estimate_range_traditional`, `estimate_days_ai_assisted`, `estimate_range_ai_assisted`, `blended_speedup`, `confidence`, and `status` per Step 5.1.
- Append a `## Revision log` section (create it in round 1; each later audit round appends its own block under the same heading):
  ```markdown
  ## Revision log
  Round <N> — audited & adjudicated <date>.
  Traditional: <X>d → <X+Y>d.  AI-assisted: <P>d → <P+Q>d.  Blended speedup: <old>× → <new>×.
  Applied (confirmed): <F# — short note (trad ±Nd / ai ±Nd)> …
  Rejected (false-positive): <F# — short note> …
  Deferred to human decision: <crisp question(s)>, if any.
  See `audit-report<-rN>.md` and `adjudication<-rN>.md` for the full trail.
  ```
- Do **not** delete the original numbers from the Estimate section silently — the revision log records the before→after for both columns so the change is auditable.

If the adjudicator left any **needs-human-decision** items, surface them — do not invent an answer.

---

## Step 5.1 — Convergence signals (compute & record — do NOT loop here)

This skill runs **exactly one audit round**. Whether more rounds are worth their cost is the **developer's** call — they sanity-check the direction first, then continue with `/run-auditors`. Re-audit rounds burnt on a plan whose core concepts are wrong are pure waste.

**Compute two signals** for the round just finished:
- `confirmed_high` — the number of findings that are BOTH severity **high** in the audit report AND ruled CONFIRMED or PARTIALLY-CONFIRMED in the adjudication.
- `delta_ratio` — `|net_delta_traditional| ÷ (the traditional likely estimate as it stood BEFORE this round's reconcile)`, from the adjudication frontmatter.

**Continuation is recommended when `confirmed_high ≥ 3` OR `delta_ratio ≥ 30%`.** (A cluster of confirmed-high findings — or a single estimate-shifting one on a small task — means the plan's foundations moved and the fixes themselves deserve a fresh adversarial pass. One or two small confirmed findings are absorbed by reconciliation alone. Tune both thresholds here.)

Set the plan frontmatter `status` accordingly:
- A trigger fired → `status: audited-round-1` — continuation recommended; `/run-auditors` will run rounds 2–3 after the developer's review.
- No trigger → `status: audited` — converged in one round; `/run-auditors` is only needed later if the developer corrects the plan.

Append the signals to this round's Revision-log block, e.g. `Signals: confirmed_high=4, delta_ratio=38% → continuation recommended`. The actual re-audit loop (rounds 2–3, same triggers, **hard cap 3 rounds total**, `unstable-needs-rescope` exit) lives in `/run-auditors` — never run it from this skill.

---

## Step 5.5 — Harvest pill feedback (you do this directly)

The agents append knowledge-drift/gap observations to `<WORKDIR>/pill-feedback.md` as they work. If the file exists and has entries:

1. For each entry, write a draft file to `.claude/knowledge-pills/_inbox/` (create the dir if missing):
   - Filename: `<YYYY-MM-DD>-<repo>-<kebab-title>.md`
   - Frontmatter: `status: pending-review`, `type: drift | gap | new-knowledge`, `target-pill: <Interlay pill title, or "new">`, `repo:`, `source-run: <WORKDIR>`, `found-by:`
   - Body: the evidence and suggested pill change, copied from the entry.
2. **Dedupe** — if `_inbox/` already holds a pending draft for the same pill + issue (from an earlier run), append the new evidence to that draft instead of creating a duplicate.
3. **Never create or edit an Interlay pill from this pipeline** — drafts only. The user reviews `_inbox/` and pushes with `/pills-sync`.

If the file is absent or empty, skip — that's a normal outcome.

---

## Step 5.6 — Write the developer summary (you do this directly)

Distill the **audited** plan into `<WORKDIR>/summary.md` — a one-page gut-check so a developer can verify the core planning decisions in ~2 minutes and correct them immediately, without reading `plan-and-estimate.md`. Write it **after** Step 5 so it carries the post-audit numbers and verdicts.

**Hard cap: ≤ 45 lines.** If it doesn't fit, cut detail, not sections — this file competes with not being read at all. Every bullet must be **falsifiable** (phrased so the developer can say "wrong") and must trace to the plan or adjudication — no new information.

```markdown
---
key: <CIAS-NNNN or omit>
status: audited
estimate: "trad <X>d (<range>) · ai <P>d (<range>) · <speedup>× · confidence <level>"
---

# <CIAS-NNNN> — <title>: one-page summary

**What we're building** — <2–3 sentences max.>

## Core decisions — tick or correct
- [ ] <approach/shape, e.g. "variant of existing multi-select, NOT a new question type">
- [ ] <contract: `METHOD /v1/...` → JSON:API `<resource>`, consumed by <saga>>
- [ ] <data: new table vs column · backfill yes/no · PHI → Lockbox yes/no>
<≤ 6 bullets — only decisions that would reshape the plan if wrong>

## Load-bearing assumptions
- [ ] <assumption — and the swing if wrong, e.g. "if org-wide, +2d/+1d">
<≤ 5 bullets — only estimate-moving ones>

## Needs your decision
- <adjudicator's human-decision items as crisp questions; or "none">

## Estimate (post-audit)
| | Likely | Range |
|---|---|---|
| Traditional | <X>d | <low>–<high> |
| AI-assisted | <P>d | <low>–<high> |
<one line: where the speedup comes from, what stays slow (QA, review, novel work)>

## Audit in one line
<r> round(s), <n> findings — <c> confirmed (net trad ±Yd / ai ±Qd); biggest: <one clause>. <If status is audited-round-1: "**rounds 2–3 pending — run `/run-auditors` after this review.**" If unstable-needs-rescope, say so in bold.>

_Full detail: `plan-and-estimate.md` · audit trail: `audit-report.md`, `adjudication.md`_
_Pills consulted: <title (source)> · … — or none — <why>_
```

The checkboxes are for the **developer** — an unticked/struck box with a margin note is the cheapest possible course-correction, caught before anyone opens the full plan.

---

## Step 6 — Report back to the user

Short summary (6–8 lines):
1. What the feature touches (repos + headline layers).
2. **Both estimates, post-audit**: `Traditional <X>d → <X+Y>d · AI-assisted (Claude Code) <P>d → <P+Q>d · ~<speedup>× faster`, with range + confidence. Note in one line what doesn't speed up under AI (manual QA, human review, novel/integration work).
3. Audit outcome in one line: `<n> findings — <c> confirmed, <p> partial, <fp> false-positive · signals: confirmed_high=<n>, delta_ratio=<n>% → continuation recommended | converged`.
4. The single most impactful confirmed change (and the per-column net delta).
5. Any **human-decision** item the adjudicator flagged (these are the real blockers).
6. **Point to `summary.md` first**: "start with `<WORKDIR>/summary.md` — one page, tick or correct the checkboxes." Then list the full artifact set under `<WORKDIR>`: `feature.md`, `interlay-context.md`, `plan-and-estimate.md`, `audit-report.md`, `adjudication.md` (plus `-r2`/`-r3` variants if the gate re-ran), `pill-feedback.md` (if any).
7. Knowledge upkeep, one line: the `Pills consulted:` line (yours + the three agents'), whether the Interlay snapshot was taken (and any pill in its `## Not found`), and `<n>` pill-feedback drafts harvested to `.claude/knowledge-pills/_inbox/` (or "none"). If n > 0, remind the user to run `/pills-sync`.

End by handing the developer the review step, phrased by status:
- `audited-round-1`: "Review `summary.md` now — if a core decision or assumption is wrong, tell me and I'll correct the plan before more agents run. When the direction looks right, run `/run-auditors <key>` (here or in a fresh session) to finish the audit loop, then `/create-phases <key>`."
- `audited` (converged): "Review `summary.md` — tell me if anything's wrong and I'll correct it (then `/run-auditors <key>` re-checks the corrections). When it looks right, run `/create-phases <key>` to confirm and phase it."

---

## Orchestration rules

- **Sequential, not parallel.** Each phase consumes the previous phase's file — planner → auditor → adjudicator must run in order, one at a time.
- **No loops in this skill.** Exactly one audit round runs here; Step 5.1 only computes signals and sets the status. Continuation rounds (2–3) are `/run-auditors`' job, after the developer has reviewed the direction — never re-run the auditor from this skill, and never loop the planner.
- **Log developer corrections.** When the user asks you to change the plan after the report, apply the edit to BOTH `plan-and-estimate.md` and `summary.md` (they must never diverge) and append `Developer correction — <date>: <what>` under `## Revision log` — `/run-auditors` relies on these entries to know the plan changed since the last audited round.
- **Fresh agent per phase.** Spawn a new `general-purpose` agent each time. Never carry one agent's reasoning into the next role; the only channel between phases is the files on disk. That independence is what makes the audit meaningful.
- **Paths are relative to the workspace root.** Subagents share this session's cwd (the workspace root), so pass `<WORKDIR>` and the `.claude/...` paths as workspace-root-relative — don't hardcode an absolute home path.
- **Pass the date.** Subagents have fresh context and may not know today's date — give it to each.
- **Capture first.** Create the dir + `feature.md` before Phase 1, even if the request is thin.
- **You never write code or edit source.** You only manage files under the working dir and apply the reconciliation edits to `plan-and-estimate.md`.
- **If a phase fails** (agent returns nothing or the expected file is missing), report which phase failed and stop — don't fabricate the missing artifact or skip ahead.
- **Don't re-litigate.** In Phase 4 you apply the adjudicator's verdicts mechanically; you are not a fourth reviewer. If you strongly disagree with a verdict, note it for the user rather than overriding it.
- **Interlay never blocks.** The Step 1.6 snapshot must never block or fail a run — on any MCP error, record that it's unavailable, proceed on the rules + code, and say so in the report.
- **Pill feedback is a byproduct.** Harvest it (Step 5.5), but never let it expand a run's scope, and never create or edit an Interlay pill from this pipeline — drafts to `_inbox/` only; `/pills-sync` is the review/push gate.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
