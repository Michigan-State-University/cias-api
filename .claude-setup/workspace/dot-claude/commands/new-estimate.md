---
name: new-estimate
description: Produce a research-backed effort estimate for a CIAS feature or ticket — two columns (traditional vs Claude Code / agentic), days + range + confidence — without writing an implementation plan or running the audit pipeline. Grounds the numbers in Interlay knowledge pills, targeted code checks, and web/context7 research on anything external.
argument-hint: <paste the Jira ticket, or describe the feature>  (add "quick" to skip research, "deep" to force it)
when_to_use: When the user wants a number — a sizing, a ballpark, a sprint-planning figure — and not an implementation plan. Use /new-feature instead when they also want the plan and the adversarial audit.
---

# /new-estimate — estimate only, research-backed

You produce **an estimate and nothing else**: no implementation plan, no phases, no audit pipeline, no production code. One agent (you), in the main loop, in minutes rather than tens of minutes.

The request is in `$ARGUMENTS` (or the user's message). If it's empty, or is a question rather than something to size, stop and ask what to estimate.

**The estimation method is not yours to invent.** `.claude/skills/new-feature/reference/estimation-rubric.md` is the single source of truth for the persona, anchors, test/QA/review percentages, AI retained-effort factors, roll-up shape, and reality check. Read it and follow it exactly — that's what keeps `/new-estimate` and `/new-feature` numbers comparable.

**What you still do internally:** a work breakdown. You cannot size what you haven't enumerated. The difference from `/new-feature` is that the breakdown stays in your context as line items feeding the table — you do not write, design, or defend a plan document.

---

## Step 0 — Resolve target & check for existing work

Derive a **ticket key** (`CIAS-NNNN`) if present and a **slug** (kebab-case, 3–6 words).

Glob `.claude/jira-tasks/` for `cias-<NNNN>-*` or `feature-<slug>`:

- **Dir exists with `plan-and-estimate.md`** → an audited estimate already exists. Report its numbers and status, and stop unless the user explicitly wants a fresh independent take. Don't silently produce a second, weaker number that competes with an audited one.
- **Dir exists without one** → reuse it as `<WORKDIR>`.
- **No dir** → create `.claude/jira-tasks/cias-<NNNN>-<slug>/` (or `feature-<slug>/` with no key). Paths are workspace-root-relative — that's your cwd.

Write the request **verbatim** to `<WORKDIR>/feature.md` if that file doesn't exist yet (same frontmatter as `/new-feature`: `key`, `title`, `created` from the currentDate reminder, `url`, `status: estimating`). If it exists, leave it alone and read it.

## Step 0.1 — Depth

Default is **standard**. Honour an explicit `quick` / `deep` in the arguments:

| Depth | Pills (Interlay) | Org/global knowledge | Code | Web / context7 |
|---|---|---|---|---|
| `quick` | index + 1–2 pills | skip | none | none |
| **standard** | every plausible pill | yes | targeted spot-checks | only for genuine external unknowns |
| `deep` | every plausible pill | yes | verify each touchpoint | always, incl. context7 on every library in play |

`quick` is for "roughly, is this 2 days or 10?" — say plainly in the output that it's unresearched. Never silently downgrade to `quick` because research looks tedious.

## Step 0.2 — One clarifying question, at most

Only if a gap would swing the estimate **by a category** — role scope, new question type vs variant of an existing one, backfill required, single-clinic vs org-wide, sync vs async. Ask with `AskUserQuestion` **now**, before research, and append the answer to `<WORKDIR>/feature.md` under `## Clarifications`. Otherwise skip — residual ambiguity becomes a documented assumption with a stated swing, which is cheaper than an interrogation.

---

## Step 1 — Knowledge pills FIRST

Read `.claude/skills/new-feature/reference/knowledge-pills-index.md` and pick **every** pill the feature plausibly touches — a full-stack feature usually needs one or two backend and one or two frontend pills. Then call `mcp__claude_ai_Interlay__get_interlay_context` with a 2–4 sentence distillation of the feature (title, domain area, repos/layers it plausibly touches) **that names those pill titles**; make one more call for any pill that didn't come back (max 3 calls). Pills before grep, always: they tell you whether the work is "copy an established pattern" (cheap, and highly AI-accelerated) or "novel" (expensive, barely accelerated), which is the single biggest lever on the number.

Record which pills you loaded. If a pill contradicts the code, **the code wins** — note the drift in the output.

## Step 2 — Organization / global knowledge (same Interlay response)

Unlike `/new-feature`, do **not** write `interlay-context.md` — hold the response in context. Besides the project pills, use the **organization** and **global** sections: HTD-wide conventions, prior similar work, and delivery norms are exactly the kind of thing that moves an estimate. Meeting summaries are background only.

Priority when sources disagree: **code > Interlay project pill > organization pill > global pill.**

If Interlay is unavailable or errors, size from `.claude/<repo>/rules/` + the code, continue, and say so in the output. It must never fail a run.

## Step 3 — Targeted code checks

You are sizing, not designing — so check what changes the *number*, and stop:

- **Does it already exist?** A pattern to copy is 0.3–0.45× retained effort; greenfield is not. Grep for the model, route, serializer, Redux module, container.
- **How big is the thing being touched?** A 900-line container or a many-column encrypted table costs more than the anchor.
- **Table size / PHI / backfill.** Check the migration history and `Lockbox`/`blind_index` usage — encrypted-column and large-table migrations jump a whole anchor band.
- **How many call sites?** `grep -c` on the symbol being changed. Fan-out is where estimates quietly blow up.
- **Roles / abilities.** How many roles in `ability/` need a rule, and how many need manual QA passes.

Verify every path, class, route, or field you name, or mark it explicitly as **new at `<path>`**. Never invent one to make a line item look concrete.

## Step 4 — Research the external unknowns (web + context7)

Skip only when everything is in-codebase pattern replication. Otherwise **research before sizing** — an unresearched integration line item is a guess wearing a decimal point.

**`WebSearch` / `WebFetch`** — for anything outside this codebase whose *actual* behaviour sets the cost:
- Third-party API capability, rate limits, auth model, sandbox availability, breaking changes (Twilio, Google TTS/Translation, Epic on FHIR, CAT-MH, Documo, AWS).
- Standards and profiles — HL7 v2.5 segments, FHIR resource shapes, accessibility/compliance requirements.
- Whether the thing is even *possible* as specified. A feasibility answer of "no, not that way" is the highest-value output this command can produce, and it must surface before a number does.

**`mcp__context7__resolve-library-id` → `mcp__context7__query-docs`** — for library-level questions where your training data may be stale: does this version support X, what's the migration cost, what's the real API surface. Use it on any library the feature would add, upgrade, or lean on heavily. Cheaper and more reliable than a web search for library docs.

Prefer **primary sources** (vendor docs, changelogs, RFCs, spec pages) over blog posts. Keep every finding to one line with its URL — these go in the output's research log and are what make the estimate defensible to someone who wasn't in the room.

Feed findings straight into sizing: a confirmed sandbox and a clean SDK pull an integration item toward the low anchor; an undocumented API, a required vendor approval, or a partner-side dependency pushes it high **and** raises the contingency %.

---

## Step 5 — Break down, then size

Enumerate line items across the rubric's categories — data & contract, backend, frontend, automated tests, manual/QA — using the `/new-feature` planner's checklist as your coverage prompt (migration/model/PHI; endpoint/routes/strong params; serializer; abilities; services; Sidekiq; integrations; AnyCable · Redux module; containers/components; Formik+Yup + i18n; routing/RBAC; models + JSON:API; specialized UI; feature flag). One line each: **what · where (verified path or "new at …") · traditional days**.

Then apply the rubric exactly:
1. Size every item in **traditional** effort against the anchors.
2. Apply the **per-category retained-effort factor** to derive AI-assisted — never one flat multiplier.
3. Tests and manual/QA are **separate line items**, never folded into implementation.
4. Justify the contingency % from your actual risks and research findings.
5. Produce the two-column roll-up, a range per column, the blended speedup, and confidence.

## Step 6 — Challenge your own number

`/new-estimate` has no auditor. Run this pass yourself, explicitly, before writing anything — and change numbers when it bites:

- **Reality check** — is the blended speedup faster than ~3×? Then QA or review got cut, or novel work was mis-tiered as scaffolding. Re-tier it.
- **Floors** — requirement clarification, design decisions, human review, and manual QA do not shrink under AI. Is the AI-assisted total above their sum?
- **The missing-work sweep** — did you count: migration *and* backfill verification; ability rules for *every* role; i18n + translation entries; the hand-written saga (the frontend is never generated from the backend); error/empty/loading states; regression QA on adjacent flows?
- **Fan-out** — did the Step 3 call-site count actually reach a line item, or get admired and dropped?
- **The confidence tell** — if three or more estimate-moving assumptions are still open, confidence is **low**. Say low. A wide honest range beats a narrow wrong one.

State in the output what this pass changed, in one line. "Nothing" is a legitimate answer only if you genuinely re-derived and nothing moved.

---

## Step 7 — Write `<WORKDIR>/estimate.md`

**Hard cap: ≤ 60 lines.** This is a number with its reasoning attached, not a document.

```markdown
---
key: <CIAS-NNNN or omit>
estimated: <today's date>
depth: quick | standard | deep
estimate_days_traditional: <likely>
estimate_range_traditional: <low>–<high>
estimate_days_ai_assisted: <likely>
estimate_range_ai_assisted: <low>–<high>
blended_speedup: <e.g. 1.9x>
confidence: high | medium | low
status: estimate-only-unaudited
---

# <CIAS-NNNN> — <title>: estimate

**What's being sized** — <2–3 sentences: the feature, and the shape of the work (repos/layers).>

## Estimate
<the rubric's two-column roll-up table: Category | Traditional | AI-assisted | Retained factor>

**Traditional: <N>d** (<low>–<high>) · calendar ≈ <N × 1.4> working days at ~0.7 focus.
**AI-assisted: <M>d** (<low>–<high>) · **<N ÷ M>×**. <one line: where the speedup comes from, what stays slow.>
**Confidence: <level>** — <why, tied to open assumptions.>

## What drives the number
- <≤ 5 bullets — the items that dominate the total and why (existing pattern to copy? novel? fan-out? integration?)>

## Assumptions — each with its swing
- [ ] <assumption> → if wrong, <±Nd trad / ±Nd ai>
<≤ 5 bullets, estimate-moving only>

## Research findings
- <finding — source URL>  <!-- omit the section entirely if depth was quick -->

## Basis
Pills consulted: <title (source)> · … (or "Interlay unavailable"). Org/global: <hits, or "none">. Code verified: <paths>. Drift found: <or "none">.
Self-check changed: <one line, or "nothing">.

_Estimate only — no implementation plan, no adversarial audit. Run `/new-feature <key>` for the planned + audited version._
```

## Step 8 — Report

Six lines, no more:
1. Both numbers with ranges and the speedup: `Traditional <N>d (<low>–<high>) · AI-assisted <M>d (<low>–<high>) · ~<S>× · confidence <level>`.
2. What it touches — repos + headline layers.
3. The one or two line items that dominate the total.
4. The biggest assumption and its swing — or a blocking feasibility finding from Step 4 if research turned one up. **Lead with the feasibility finding if there is one.**
5. Basis in one line: `Pills consulted: <title (source)> …` (or Interlay unavailable), research done/skipped.
6. `<WORKDIR>/estimate.md` — and: "unaudited. `/new-feature <key>` if you want the plan and the adversarial pass."

---

## Rules

- **Estimate only.** No `plan-and-estimate.md`, no phases, no `summary.md`, no source edits. The only file you write is `estimate.md` (plus `feature.md` on first capture). If the user wants the plan, point them at `/new-feature` — don't drift into being it.
- **The rubric is not negotiable.** Read `estimation-rubric.md` every run. Don't estimate from memory of it; the anchors get tuned.
- **Pills before grep. Research before sizing an unknown.** Both orders exist because reversing them produces confident wrong numbers.
- **Never invent a path, class, route, or field.** Verify it or mark it "new at …".
- **Interlay and research are best-effort, never blockers.** On failure, note it in the Basis line and carry on.
- **Say "I don't know" with a range.** Low confidence plus a wide range is a correct answer. False precision is not, and it's the failure mode that costs someone a sprint.
- **This is unaudited and must say so** — in the frontmatter status, in the file footer, and in the report. It's the honest difference between this and `/new-feature`.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
