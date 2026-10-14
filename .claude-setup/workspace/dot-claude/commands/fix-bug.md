---
name: fix-bug
description: Plan and implement the fix for a /new-bug-triaged CIAS ticket — confirms the verified hypothesis with the developer, proves the root cause with a failing test, writes the minimal fix + regression test on a fix branch, and STOPS before committing (the developer commits manually).
argument-hint: "[CIAS-NNNN or slug]  (omit in the triage session — it infers the workdir)"
when_to_use: After /new-bug triage, once the developer has reviewed summary.md and the hypothesis holds. Works in the triage session or any later session.
---

# /fix-bug — from confirmed triage to a verified fix

Bridges triage and fix. Bugs don't get the feature pipeline's multi-agent planning — they get a confirmed hypothesis, a **failing test that proves the root cause**, a minimal fix, and an honest close-out. Status flow in `ticket.md`: `triaging → triaged → fix-in-progress → fixed`.

## Step 0 — Resolve

1. From `$ARGUMENTS`: `CIAS-NNNN` or slug → glob `.claude/jira-tasks/` for `<dir>`. No argument: use this session's triage workdir if `/new-bug` just ran; otherwise list dirs whose `ticket.md` has `status: triaged` and ask.
2. Read `ticket.md`, `log-analysis.md`, `summary.md`, and `reproduction.md` (and `triage-verification.md` for open questions). Missing analysis or summary → stop; run `/new-bug` first.

## Step 1 — Confirmation gate (the developer confirms the hypothesis)

1. Check `ticket.md` `status`:
   - `triaging` → stop; triage didn't finish.
   - `fixed` → nothing to do (a regression is a new ticket).
   - `fix-in-progress` → offer to resume: read `## Fix notes` / `## Remaining` in `log-analysis.md` first.
2. Show `summary.md`'s **Core claims** plus any open question from the verifier, then ask (AskUserQuestion): **Confirm hypothesis** / **I have corrections**.
3. Corrections → apply them to BOTH `summary.md` and `log-analysis.md` (they must not diverge), logged under a `## Corrections` heading in `log-analysis.md` (`Developer correction — <date>: <what>`). A correction that invalidates the hypothesis entirely → re-triage before fixing.
4. On confirm: `ticket.md` `status: fix-in-progress`.

## Step 2 — Prove the root cause (failing test first)

1. Load the knowledge pills for the affected subsystem before touching code: `<dir>/interlay-context.md` (triage's snapshot) first; fetch anything it lacks with `mcp__claude_ai_Interlay__get_interlay_context` (name the pill title).
2. Start from `<dir>/reproduction.md` — triage already wrote verified Web-UI and Rails reproduction scenarios. Translate scenario **B (backend)** into a **failing automated test** at the right layer (RSpec for backend, Jest/saga test for frontend): its "Observe" line is what the test asserts on. The failing test is both the proof of the root cause and the future regression test. If a test genuinely can't capture it (third-party timing, infra), run the scenarios manually (`rails c`, curl, `playwright-cli` for the UI path — local dev, never destructive on shared envs) and justify the missing test later in Fix notes. If reality diverges from `reproduction.md`, correct that file — it's QA's script later.
3. If the actual root cause differs from the confirmed hypothesis: update `log-analysis.md` (add `## Root cause`) and `summary.md`, and tell the developer before proceeding.
4. **Scope check**: if the real fix balloons beyond a bug — schema change, new endpoint, cross-repo feature work — stop and recommend `/new-feature`. Don't smuggle a feature through a bugfix.

## Step 3 — Fix

1. Git, per affected repo (run inside `cias-api/` / `cias-web/`): warn on unrelated uncommitted changes; reuse the ticket's existing branch or create `fix/cias-<NNNN>-<slug>` from `dev`. A production hotfix (straight to `master`) instead follows `.claude/git-and-merge-strategy.md` / `.claude/cias-web/rules/hotfix-flow.md` — ask which applies if the ticket doesn't say.
2. **Minimal diff**: fix the cause, not the symptom; no drive-by refactors; follow the repo's conventions.
3. If triage flagged an instrumentation gap at the failure point (silent failure), close it as part of the fix when cheap (a log line, a `Sentry.captureException`) — note it in Fix notes.

## Step 4 — Verify

1. The Step 2 failing test now passes. Run it, the adjacent specs (regression on the surrounding flow), and lint: `bundle exec rspec <paths>` + `bundle exec rubocop` (cias-api); `npm test -- <paths>` + `npm run lint` (cias-web).
2. Walk the ticket's reproduction steps one by one — state plainly whether the fix covers each. Report failures faithfully.

## Step 5 — Close out

1. **Status, honestly**: tests green + repro steps covered → `ticket.md` `status: fixed`; anything unmet → stays `fix-in-progress` with a `## Remaining` list in `log-analysis.md`. Never mark fixed on red.
2. Append `## Fix notes` to `log-analysis.md`: root cause (one paragraph), the fix (files + why this shape), regression-test path, instrumentation added, anything QA should probe.
3. **Pill feedback**: drift/gaps/new-knowledge discovered while fixing → `<dir>/pill-feedback.md` (`found-by: fixer`), then harvest to `.claude/knowledge-pills/_inbox/` per `.claude/skills/new-feature/SKILL.md` Step 5.5 rules (dedupe included).
4. **Hand the commit to the developer**: `git diff --stat` per touched repo + a suggested commit message (e.g. `CIAS-NNNN: fix <symptom>`). Do **not** commit.
5. Next steps: `/qa-scenarios-creator <key>` or `/qa-run` to QA the fix; `/pills-sync` if `_inbox/` gained drafts.
6. End the close-out with the `Pills consulted:` line — triage's snapshot plus anything you fetched while fixing.

## Hard rules

- **NEVER `git commit`, `git push`, or open a PR** — the developer commits manually, always. End with the diff and the suggested message.
- **A fix without a regression test isn't done** — exceptions must be explicitly justified in Fix notes.
- Minimal diff; feature-sized scope goes to `/new-feature`, not through this command.
- Never mark `fixed` with failing tests or unverified reproduction steps — an honest `fix-in-progress` + `## Remaining` beats a false green.
- Never edit `ticket.md`'s captured body — frontmatter `status` only.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
