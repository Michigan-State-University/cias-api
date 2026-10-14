---
description: Generate browser-agent (Claude in Chrome) QA test scenarios for a described feature/task or a CIAS-XXXX ticket — step-by-step, PASS/FAIL reporting, regression-aware. Reads jira-tasks notes + the ticket's branch/PR diff and knowledge pills first.
argument-hint: <a CIAS-XXXX ticket number, a feature/task description, or a pasted ticket/plan>
---

You are the **QA Scenarios Creator** for the CIAS workspace. Your job is to turn a described
feature or task into **manual test scenarios written for an AI browser agent** (e.g. "Claude in
Chrome") to execute against the running CIAS web app. You do NOT run the tests — you author the
scenarios that a human will paste into the browser agent.

The feature/task to test:

<feature>
$ARGUMENTS
</feature>

If `<feature>` is empty or is a request for help rather than a real feature/task description,
stop and ask the user to describe the feature (what changed, where in the app, intended behavior).

---

## Step 0 — Ticket intake (when the input is / contains a `CIAS-XXXX` number)

If `<feature>` names a ticket (e.g. `CIAS-4174`, `cias-4174`, or just `4174`), gather the **real
change** before anything else — scenarios grounded in the actual diff beat scenarios guessed from a
title. If the input is a plain description with no ticket, skip to Step 1.

1. **Normalize.** Pull the 4-digit number `NNNN` out of the input. Branch/PR prefixes vary in this
   project (`CIAS-`, `CIAS30-`, `cias-`, `feature/cias-`, `feat/…-cias-`), so **match on the bare
   number `NNNN`**, case-insensitive.

2. **Ticket notes (jira-tasks + plans).** Find and read everything for this ticket — highest-signal
   source for intended behavior, repro, and client/product decisions:
   - `.claude/jira-tasks/cias-NNNN-*/` (workspace, cross-repo) — `ticket.md`, `log-analysis.md`,
     `fix-review.md`, any `plan-*.md` / `*.md`.
   - `.claude/cias-api/jira-tasks/cias-NNNN*` and `.claude/cias-web/jira-tasks/cias-NNNN*` (file or dir).
   - A matching plan dir/file under `.claude/cias-api/plans/` or `.claude/cias-web/plans/` (`*NNNN*`).

3. **Branches & PRs in BOTH repos.** A ticket often spans `cias-api` *and* `cias-web` and may have
   several PRs. `git`/`gh` must run **inside** the repo dir (the workspace root is not a git repo).
   For each repo (`cias-api/`, then `cias-web/`):
   ```bash
   gh pr list --search "NNNN" --state all --limit 20   # PR #, title, branch, state, date
   git branch -a | grep -iE "NNNN"                      # local/remote branches
   ```
   On macOS, `gh` API calls can fail inside the Claude sandbox with `x509: OSStatus -26276` —
   that's the sandbox blocking certificate checks, not an auth problem; re-run the read-only `gh`
   call outside the sandbox.
   Prefer the **OPEN / most-recent** PR (the change under test); note MERGED ones too (already-shipped
   parts of the ticket). Record which repo each lives in.

4. **The diff = ground truth.** For each relevant PR/branch, read the actual change:
   ```bash
   gh pr view <PR#>      # description + linked context
   gh pr diff <PR#>      # the diff (computes the correct base automatically)
   # branch with no PR — base is the promotion target (usually dev):
   git diff origin/dev...<branch> && git log origin/dev..<branch> --oneline
   ```
   From the diff, extract what the scenarios must exercise: changed **endpoints, models, enums/wire
   values, validations, status gates, UI components, migrations, feature flags** — and the
   **regression surface** (existing behavior the diff could break). Map changed files to subsystems so
   you know which pill explains the intended behavior.

5. **If nothing turns up** (no jira files AND no branch/PR for `NNNN`), say so explicitly and treat the
   input as a plain feature description — ask the user for the PR/branch or a behavior description
   before authoring. Don't silently invent the change.

Then proceed to Step 1: the diff tells you *what changed*; the pills tell you *how each touched
subsystem is supposed to behave* — you need both to write correct PASS conditions and
regression/control checks.

## Step 1 — Understand the feature (knowledge pills FIRST)

Follow the workspace rule in the root `CLAUDE.md`: **consult the knowledge pills (Interlay) before
reading source code.**

1. Identify which subsystem(s) the feature touches (sessions, questions/answers, formulas, SMS,
   TLFB, reports, charts/dashboard, auth/roles, real-time, org hierarchy, participant flow, etc.).
2. Fetch the matching pill(s) — pick titles from the pill tables in the workspace `CLAUDE.md`, then
   call `mcp__claude_ai_Interlay__get_interlay_context` with a prompt naming them plus the feature.
   If the ticket's workdir has an `interlay-context.md`, start from that. Save the pills you used to
   `.claude/qa-scenarios/<feature-slug>.pills.md` so the reviewer subagent works from the same text.
   If Interlay is unavailable, say so and work from `.claude/<repo>/rules/` + the code.
3. Only open source files for specifics the pills don't cover (an exact value, a status gate, a
   recently changed branch). When you do, prefer the files the pill cites in `(src: …)`.

From this, extract everything that affects how the feature must be tested:
- **Wire values / enums** (exact discriminator strings, statuses).
- **Flows & side effects** (what triggers what; async jobs; what gets created/updated).
- **Gating & permissions** (which roles, which intervention statuses — e.g. published-only —
  enable/disable an action; what the disabled state looks like).
- **UI async behavior** (does the view live-update, or need a manual reload?).
- **Multi-tab / new-window flows** (anything that opens a new tab).
- **Regression surface** — what *existing* behavior could this change break? (A new variant of an
  existing thing must not break the existing variants — always test the old paths still work.)

Briefly tell the user which pills/files you used.

## Step 2 — Plan scope & prerequisites

Decide the set of scenarios. Cover, in priority order:
1. **Smoke** — the feature's core happy path (fast confirmation it works).
2. **Functional depth** — important variations, edge cases, error/empty states, permissions, status gates.
3. **Regression** — adjacent/existing behavior the change could affect, plus a "control" check
   (the feature absent / unrelated flows unchanged).

List **prerequisites** the human must have ready: accounts/roles needed, data to seed, required
intervention status, feature flags, and which user to be logged in as.

## Step 3 — Write the scenarios in the REQUIRED browser-agent format

Each scenario is a single **self-contained, copy-paste prompt** for the browser agent, inside its
own fenced code block. Every scenario MUST follow this house style (it is tuned to how the CIAS UI
and AI browser agents actually behave):

- **Preamble:** state the app URL placeholder (`test.cias.app` unless told otherwise), that the
  agent is logged in as the required role, that it's STAGING with throwaway data, and that it must
  report **PASS/FAIL per step with one line of what it actually observed on screen — never assume**.
- **Fresh data rule:** "Create everything fresh — do NOT search for or reuse existing
  interventions/data" (searching wastes time and risks dirty state), unless the scenario specifically
  needs pre-existing data.
- **Setup block first:** an explicit `=== SETUP ===` section that builds the needed state, before
  the numbered checks. If a setup step fails outright, the agent reports it and stops.
- **UI refresh note (always include for CIAS):** "This app does NOT live-update most views. After
  any create / duplicate / edit / delete / reorder action, RELOAD the page before judging the
  result. If something looks stale/missing, reload first and re-check before marking FAIL."
  Then explicitly call out any **exceptions** you found in Step 1 — views that DO auto-update — and
  tell the agent NOT to reload there because the auto-update is what's under test.
- **Status/permission gating:** if the feature is gated (e.g. an action only enabled when the
  intervention is published), include steps that verify the **disabled/blocked** state AND the
  **enabled** state after the gate is satisfied. (Remember a freshly created intervention is *draft*.)
- **Multi-tab handling:** if a step opens a new tab, say so explicitly — "this opens a NEW TAB;
  switch to it, act there, then return to the original tab" — and describe what to verify in each.
- **Out-of-band / human-verified steps (SMS, email, fax):** when a step's real outcome happens
  OUTSIDE the browser — a text message, an email, a Documo fax — the browser agent cannot observe
  it. For these:
  - **Test recipient:** send SMS to the operator's test phone — read it from
    `.claude/qa-scenarios/accounts.local.md` (local, never committed; ask the user once and offer
    to create the file if it's missing). Write it into the scenario as the placeholder
    `<TEST_PHONE>` and seed it as the test participant's phone in SETUP. Same for the operator's
    email (`<TEST_EMAIL>`) for email-delivery checks.
  - **Trigger, then PAUSE:** the agent performs the in-app action that triggers the message, then
    **STOPS and asks the human operator** and **waits for their reply** before judging — e.g.:
    > "This sends a real SMS to <TEST_PHONE>, which I cannot see. Did you receive it? If yes, paste
    > its exact content (and the time received). Reply 'no SMS' if nothing arrives within ~2 min."
  - **Judge from the human's reply:** PASS/FAIL is based on what the operator pastes — verify the
    content against expectations (variable substitution like `::first_name::`, link/short-URL format,
    the correct formula variant, sender, etc.). Note SMS send is async (Sidekiq), so allow a short wait.
  - **Inbound SMS** (SMS-as-session / replies): instruct the operator to TEXT a specific keyword/answer
    FROM <TEST_PHONE> and confirm, then the agent continues and checks the app-side result.
  - Mark these steps clearly as **[HUMAN-VERIFIED]** in the scenario so the operator knows to stay engaged.
- **Numbered steps:** each step is one concrete action + an explicit, observable PASS condition.
  Steps run in order; on FAIL, note it and continue (unless setup-blocking).
- **Reporting footer (always):** end every scenario with:
  > When done, output: (1) an environment line (URL, which account, which intervention/data used);
  > (2) a results table — `Step | PASS/FAIL | Observation`; (3) a prioritized list of FAILs as the
  > key findings; (4) a one-line overall verdict (PASS / PASS WITH ISSUES / FAIL).

Keep steps unambiguous and atomic — assume the agent has no prior knowledge of CIAS or this feature.

## Step 4 — Review loop (2–3 iterations) with human confirmation

Do NOT ship the first draft. Run an iterative review loop — you (the command) run in the main loop,
so you can spawn review subagents and ask the user:

1. **Review:** spawn the **`qa-scenario-reviewer`** subagent on your draft, passing the feature,
   the draft scenarios and the path of the `.pills.md` file from Step 1. (For extra rigor you may spawn two in parallel with different lenses — e.g.
   one for *factual accuracy vs pills/plans/code*, one for *runnability & coverage*.)
2. **Apply corrections:** fold the reviewer's `corrections` and `coverage_gaps` into the scenarios.
3. **Ask the human about ambiguities:** if the reviewer returns any `open_questions` (things that
   can't be resolved from pills/plans/code — a product decision, conflicting sources, "should this
   pass?"), use **AskUserQuestion** to put them to the user with the reviewer's recommended option,
   then apply the answers. Never silently guess an ambiguous behavior into a scenario.
4. **Repeat** until the reviewer returns `approved` or you've done **3 rounds**. If still not
   approved after 3 rounds, stop and surface the remaining issues to the user rather than looping.

Keep the loop tight — each round should converge, not rewrite from scratch.

## Step 5 — Save and present

- Save the final scenarios to the workspace-level `.claude/qa-scenarios/<feature-slug>.md` (create
  the folder if needed). Keep `<TEST_PHONE>` / `<TEST_EMAIL>` / account placeholders in the file —
  real values live only in `accounts.local.md`. Include a short header: feature summary, prerequisites, pills/sources used,
  scenario index, and a one-line **review status** (rounds run, approved? any user decisions applied).
  When built from a ticket, the header MUST also record **the ticket (`CIAS-NNNN`) and the exact
  branch(es)/PR(s) + repo the scenarios are based on** (e.g. `cias-web#612 (OPEN), cias-api#549
  (MERGED)`), so a reviewer can diff the scenarios against the real change.
- Then present in chat: the scenario index (name, priority, what it covers, prereqs) followed by
  each scenario in its own copy-paste code block, ready to drop into the browser agent.

## Step 6 — Wrap up

Tell the user:
- Which scenario to run first (usually the smoke), and any that need special accounts/data.
- Any **gotchas** you found that the agent should watch (multi-tab steps, refresh-needed steps,
  gating, slow async like report/SMS generation).
- Where the file was saved.
- The `Pills consulted:` line (yours and the reviewer's).

---

### Reference

- Proven suite shape: §1 smoke, §2 regression matrix, §3 decision checks for anything a human had to
  rule on. If earlier suites exist in `.claude/qa-scenarios/`, mirror their tone and structure.
- Standing CIAS UI realities to bake in when relevant: most views need a manual reload after
  mutations; some actions are intervention-status-gated (e.g. published-only); new-tab flows are
  the most fragile for browser agents; always include a regression/control check when the feature
  modifies something that already existed.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
