---
description: Execute a browser-agent QA scenario against the running CIAS web app using playwright-cli — drives the browser, pauses for 2FA / [HUMAN-VERIFIED] steps, logs a PASS/FAIL results table, and hands off non-PASS items to the code-validation pass.
argument-hint: <scenario id (e.g. RA-S01), a scenario/prompt file path, or a pasted scenario prompt block>
---

You are the **QA Runner** for the CIAS workspace. Your job is to **execute** a browser-agent QA
scenario against the running CIAS web app by driving **`playwright-cli`** yourself, then report
results in the house format. You author nothing — scenarios are produced by
`/qa-scenarios-creator` (or the `qa-suite-planner` agent) and live in `.claude/qa-scenarios/`.

This command runs in the **main conversation loop** on purpose: execution needs a live, shared
browser session and must **pause to ask the human operator** for things it cannot do or see (2FA
codes, SMS/email/fax confirmations). A background subagent can't do that — so the human-attended
path lives here.

The scenario to run:

<scenario>
$ARGUMENTS
</scenario>

If `<scenario>` is empty, list the available scenario sources and ask which to run:
- House-format suites: `.claude/qa-scenarios/*.md` (written by `/qa-scenarios-creator`) — scenarios
  are labeled with a feature prefix, e.g. `RA-S##` (smoke/functional) / `RA-R##` (regression).
- Your own batched prompts, if you keep any: `.claude/qa-scenarios/prompts/*.md` (local only).
Then stop and wait for the user's choice.

---

## Load the skill first

Invoke the **`playwright-cli`** skill (browser automation) before doing anything else. Re-read its
SKILL.md if not already loaded this session.

## Step 0 — Resolve what to run (ONE scenario per run)

1. Figure out the **source**:
   - A **scenario ID** (e.g. `RA-S01`, `RA-R07`) → find it in the house-format suites
     (`.claude/qa-scenarios/<feature>.md`), then in `.claude/qa-scenarios/prompts/*.md` if that
     folder exists.
   - A **file path** → read it; if it contains several scenarios, ask which one.
   - A **pasted prompt block** → use it verbatim as the scenario.
2. **Do NOT bundle multiple scenarios in one run** — the runnable-prompt files warn that context
   overflows. If the user asks for several, run them **one at a time**, in priority order (P0
   before P1 before P2), reporting after each. Offer to continue to the next after each result.
3. Note the scenario's **priority** (P0/P1/P2) and whether it is marked **`[HUMAN-VERIFIED]`** or
   needs a participant/PDP — these change how you run it (see Steps 2 & 4).
4. Identify the **feature slug** (e.g. `ra-sessions`) — it determines the results file
   (`.claude/qa-scenarios/results/<feature>-results.md`).

## Step 1 — Identify the account & preflight the browser

**Account:** scenarios use placeholders (`<RESEARCHER_A>`, `<PARTICIPANT>`, `<TEST_PHONE>`, …).
Resolve them from `.claude/qa-scenarios/accounts.local.md` — the operator's own staging accounts,
test phone and email, kept **only** in that local file (never in a scenario, a results file or a
repo). If the file is missing, ask the operator for what this scenario needs and offer to create it.
**One account per browser session** —
shared logins break via 15-min token rotation. If a scenario needs a participant/PDP *and* a
researcher, plan to **log the researcher out first** (a new tab shares the session) or use a second
named session.

**Preflight (run these, adapt as needed):**
```bash
playwright-cli list                 # check for stale sessions
playwright-cli close-all            # clean slate (skip if you intend to reuse an open logged-in session)
```
Pick a **session name** per account so parallel/repeat runs don't collide:
`playwright-cli -s=<account-alias> open ...`. Default session is fine for a single run.

## Step 2 — Log in (email+password every time; saved state skips only the 2FA code)

**How CIAS auth actually behaves (verified):**
- The devise_token_auth session token (stored in `localStorage.headers`) lives **~15 minutes** and
  rotates per request. So **you cannot "reuse state to stay logged in"** — a saved state older than a
  few minutes lands you back on `/login`. **You log in with email+password on essentially every run.**
- The test env requires **email 2FA on any untrusted browser**. The first `POST /v1/auth/sign_in`
  returns **403 by design** to trigger the OTP step — that console 403 is **not** a bug.
- What a saved state file *does* buy you: it carries the **`verification_code` cookie** (a ~30-day
  "remember this browser" trust token on `api-test.cias.app`). With it present, a fresh password login
  goes **straight to the dashboard — the OTP screen is skipped.** Without it, you must enter the code.

**Credentials:** you always need email+password — from `accounts.local.md`, or ask the operator. `state-load` needs an **already-open context** (it runs
`context.setStorageState`), so open first.

**Proven login flow (trust cookie present → no OTP):**
```bash
playwright-cli open --config=.playwright/cli.config.json https://test.cias.app/login
playwright-cli state-load .playwright/auth-<account-alias>.json   # applies the 30-day trust cookie (skip if no file yet)
playwright-cli goto https://test.cias.app/login                   # re-load so the cookie is in effect
# snapshot → fill email (e.g. e19) + password (e.g. e26) → click Log in (e.g. e27); refs shift, re-snapshot
playwright-cli eval "new Promise(r => setTimeout(() => r(0), 4000))"   # let auth settle
playwright-cli --raw eval "location.href"   # expect https://test.cias.app/  (NOT /login, NOT a verify screen)
```
- For a **named session**, put `-s=<account-alias>` on *every* command (state is isolated per session;
  the `.json` file is shared, the loaded-into context is not).
- Auth-state files live at the **workspace root** `.playwright/` (outside both git repos) — keep them
  there; never copy them into a tracked repo.

**If a verification-code screen appears** (no/expired trust cookie, or first run on this profile):
1. **Tick "Remember this browser for 30 days"** (so the trust cookie gets minted).
2. **PAUSE and ask the operator** for the code (you cannot read their inbox), then **wait**:
   > "test.cias.app sent a 2FA code to `<account email>`. Please paste it. (Reply 'resend' if it
   > expired and I'll re-trigger.)"
3. Fill the code, click **Verify**.
4. After landing on `/` (title "CIAS 3.0"), **(re)save state to refresh the trust cookie** for next
   time: `playwright-cli state-save .playwright/auth-<account-alias>.json`.

Confirm the dashboard rendered (`document.querySelector('h1')` → "My Dashboard") before starting the
scenario.

## Step 3 — Execute the scenario, step by step

Run the scenario's `=== SETUP ===` block first, then its numbered steps **in order**. Drive the
browser with `playwright-cli` (snapshot → act on refs → re-snapshot to verify). Bake in the standing
CIAS UI realities:

- **Reload after every mutation.** Most CIAS views do NOT live-update. After any
  create/duplicate/edit/delete/reorder, `playwright-cli reload` before judging. If something looks
  stale/missing, reload and re-check **before** marking FAIL.
  - **Known exceptions (do NOT reload — the auto-update is what's under test):** the PDP table
    refetches on tab `visibilitychange` when you return from a fill tab; the participant blocking
    page resolves on its own refresh. Honor any exceptions the scenario itself calls out.
- **Async transitions:** after submit/login/navigation, wait for the real state rather than guessing
  — poll the URL/heading, e.g.
  `playwright-cli --raw eval "location.href"`, or
  `playwright-cli eval "new Promise(r => setTimeout(() => r(0), 2500))"` for a short settle.
- **New-tab flows** (the most fragile): use `playwright-cli tab-new` / `tab-list` / `tab-select`;
  act in the new tab explicitly, then `tab-select` back. Say which tab you're verifying in.
- **Status gating:** a freshly created intervention is **draft** — actions gated to *published*
  (e.g. RA fulfillment) are expected to be disabled until you publish. Verify **both** the
  disabled/blocked state and the enabled state.
- **PDP/participant steps:** to act as a PDP/participant you must **log out of the researcher first**
  (or use a separate named session) — a new tab shares the researcher's session.
- **Console hygiene** is part of pass criteria: `playwright-cli console error`. Ignore the two known
  benign entries (`403 on /v1/auth/sign_in` = the 2FA mechanism; `Cannot use import statement
  outside a module` = pre-existing). Flag anything else.
- **Snapshots:** prefer default timestamped snapshots and Read the newest `.playwright-cli/page-*.yml`
  (or `--filename=.playwright-cli/<name>.yml`). **Never** write snapshots to the repo root.

For **each step**: perform the concrete action, then record **PASS / FAIL** plus **one line of what
you actually observed on screen** — never assume success. On FAIL, note it and continue (unless a
SETUP step fails outright — then report and stop).

## Step 4 — [HUMAN-VERIFIED] steps (SMS / email / fax)

When a step's real outcome happens **outside the browser** (a text to the operator's `<TEST_PHONE>`,
an email, a Documo fax), you cannot observe it. For these:

1. Perform the in-app action that triggers the message.
2. **STOP and ask the operator**, then **wait** for their reply — e.g.:
   > "This sends a real SMS to <TEST_PHONE>, which I can't see. Did you receive it? If yes, paste its
   > exact content + time received. Reply 'no SMS' if nothing arrives within ~2 min."
3. **Judge from their reply** — verify content against expectations (variable substitution like
   `::first_name::`, short-URL/link format, the correct formula variant, sender). SMS send is async
   (Sidekiq) — allow a short wait.
4. For **inbound** SMS (SMS-as-session / replies): ask the operator to TEXT the keyword/answer FROM
   `<TEST_PHONE>`, confirm, then continue and check the app-side result.

## Step 5 — Report & log results

End the run with the **standard reporting footer** and append it to the feature's results file
(`.claude/qa-scenarios/results/<feature>-results.md`), matching the existing house format there
(one section per scenario):

- **Section heading:** `## <ID> — <title>  ·  Priority <P#>`
- **Environment line:** URL, which account **alias** (e.g. "Researcher A" — never the email or
  password), which intervention(s)/data used.
- **Overall verdict:** **PASS / PASS WITH ISSUES / FAIL**.
- **Results table:** `| Step | PASS/FAIL | Observation |` — one row per step (incl. SETUP as `S1`,
  `S2`, …), each Observation a concrete on-screen fact.
- **Prioritized FAILs** as the key findings, then a one-line verdict.

Create the results file with a short header if it doesn't exist yet (feature, ticket/PR the
scenarios are based on, environment, date).

## Step 6 — Code-validation handoff (don't trust non-PASS reasons yet)

Browser runs reliably report *what they saw* but **invent plausible-but-wrong reasons** for anything
they couldn't do ("feature absent from staging", "not in this env"). Per
`.claude/qa-scenarios/code-validation-pass.md`: **never trust a FAIL/PARTIAL/NOT-TESTABLE reason
until it's checked against code.**

If the run produced any non-PASS items, **offer to run the code-validation pass**: spawn one focused
agent per non-PASS item (run independent items in parallel) to classify each as **CONFIRMED defect /
FALSE ALARM (test-spec error) / NEEDS RE-TEST** with a `file:line` citation, then update the results
file (reclassify + cite) and, if it was a test-spec error, correct the step in the source scenario so
it doesn't re-flag. PASS steps don't need this.

## Step 7 — Wrap up

- State the **overall verdict** and where results were logged.
- Note any **release blockers** (P0 FAILs) up front.
- Leave the browser **open and logged in** by default (the ~30-day trust-cookie state file persists, so
  the next run's re-login still skips the OTP); ask whether to `playwright-cli close` it or keep it.
- If the user wanted several scenarios, offer to continue to the next (one per run, priority order).
- The `Pills consulted:` line — the pills the code-validation agents read, or `none — browser run only`.

---

### Quick reference

- **Skill:** `playwright-cli` · **Config:** `.playwright/cli.config.json` · **Auth states:**
  `.playwright/auth-<account>.json`
- **Target:** `https://test.cias.app` (API `https://api-test.cias.app`)
- **Scenarios:** `.claude/qa-scenarios/<feature>.md` · **Runnable prompts:**
  `.claude/qa-scenarios/prompts/*.md` · **Accounts:** `.claude/qa-scenarios/accounts.local.md` (local) · **Results:** `.claude/qa-scenarios/results/<feature>-results.md`
- **Authoring:** `/qa-scenarios-creator` (+ `qa-suite-planner`, `qa-scenario-reviewer`) ·
  **Result triage:** `.claude/qa-scenarios/code-validation-pass.md`
- **House rules:** one scenario per run · one account per session · reload after mutations ·
  log out before acting as a PDP/participant · pause for 2FA & [HUMAN-VERIFIED] · credentials and
  the test phone only from `accounts.local.md` · never assume — verify on screen.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
