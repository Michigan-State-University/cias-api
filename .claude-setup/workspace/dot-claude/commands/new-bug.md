---
description: Triage a new CIAS Jira bug ticket — capture it under .claude/jira-tasks/cias-XXXX-<slug>/ and produce a log-visibility analysis (LogRocket / Sentry / Rails / Sidekiq).
argument-hint: <paste the Jira ticket content>
---

You are starting the **new-bug triage flow** for the CIAS workspace. The user has provided a Jira bug ticket as the argument:

<ticket>
$ARGUMENTS
</ticket>

If the ticket content above is empty or clearly a request for help rather than a real ticket, stop and ask the user to paste the ticket.

Do NOT propose a fix yet. Your only job in this flow is **capture + log-visibility analysis**. Fix planning is a separate, follow-up step.

---

## Step 1 — Capture

Extract from the ticket:
- **Ticket key**: a `CIAS-NNNN` identifier. If missing, ask the user once before proceeding.
- **Title / one-line summary**: derive a **kebab-case slug**, 3–6 words, describing the bug (e.g. `sms-not-sent`, `report-pdf-empty`, `tlfb-calendar-overflow`). Keep it factual — describe the symptom, not the suspected cause.

Create the directory:

```
.claude/jira-tasks/cias-<NNNN>-<slug>/
```

Save the **raw ticket verbatim** to `ticket.md` inside that dir, with this frontmatter:

```markdown
---
key: CIAS-NNNN
title: <full ticket title>
created: <today's date YYYY-MM-DD>
url: <Jira URL if present in the ticket; otherwise omit>
status: triaging
---

<paste the full ticket body here, including reproduction steps, expected/actual, attachments references, comments — whatever the user provided>
```

Before creating, glob for an existing dir matching `cias-<NNNN>-*` — the slug may have been chosen differently before. If a match exists, **append to that dir** (don't create a new one, don't overwrite), and tell the user you're continuing an existing investigation.

Use the date from your environment context (e.g. the `currentDate` system reminder) for the `created` field — don't ask the user.

---

## Step 1.5 — Interlay knowledge snapshot (never block on it)

Knowledge pills live in Interlay, not on disk. Pick the pills covering the suspected subsystem from the tables in the workspace `CLAUDE.md` (by their "Load when working on…" column), then call `mcp__claude_ai_Interlay__get_interlay_context` with a 2–3 sentence distillation of the bug (symptom, suspected area, repos) **that names those pill titles**. If a pill you picked didn't come back, make one more call naming just the missing ones (max 3 calls). Write `<dir>/interlay-context.md`:

1. Open with the priority rule: **code > Interlay project pill > organization pill > global pill.** Meeting summaries are background only.
2. `## Project pills` — the `<project_knowledge>` pills **in full**, each under `### <pill title>` (keep the `(src: …)` citations — Step 2 and the verifier rely on them).
3. `## Organization / global knowledge` — copy **in full** (keep a literal "No relevant pills." placeholder — it means the search found nothing, not that the step was skipped).
4. `## Meeting summaries` — verbatim only if they mention this symptom or area; otherwise "omitted".

If the Interlay tools are unavailable or every call fails, write the single line `Interlay unavailable on <date> — triaged from .claude/<repo>/rules/ and the code.` and continue. Note in the final report whether the snapshot was taken.

---

## Step 2 — Locate the bug in the code

**Knowledge pills FIRST.** Before grepping, read the pills in `<dir>/interlay-context.md`. If the investigation moves into a subsystem the snapshot doesn't cover, fetch that pill with `get_interlay_context` (name its title) and append it to the snapshot. A pill usually names the exact files (`(src: …)`) — then drop to code to verify. If a pill and the code disagree, the code wins — record the drift (Step 4.7).

Identify the suspected affected area. Determine:
- **Repo(s)**: `cias-api`, `cias-web`, or both.
- **Component / module**: specific file paths (controller, service, saga, container, job class).
- **Trigger**: user action, scheduled job, webhook, websocket message.

Use `Read`, `Grep`, and `Glob` against `cias-api/` and `cias-web/` to **verify** your claims — don't speculate about file paths or class names. If the ticket mentions specific UI text, grep for it in `cias-web/app/translations/` or component messages. If it mentions an API error or endpoint, grep `cias-api/app/controllers/v1/` and `cias-api/config/routes.rb`.

Consult the workspace rule files when you need stack-specific behavior:
- `.claude/cias-api/rules/sidekiq.md` — queue conventions, retry behavior
- `.claude/cias-api/rules/api_controllers.md` — controller/serializer patterns, error handling
- `.claude/cias-api/rules/integrations.md` — Twilio, Google TTS, HFHS, Epic, CAT-MH, Documo
- `.claude/cias-api/rules/encryption_security.md` — Lockbox fields, blind indexes
- `.claude/cias-web/rules/error-handling-and-monitoring.md` — Sentry + LogRocket setup, sanitizer list, toast pattern
- `.claude/cias-web/rules/api-and-auth.md` — axios interceptor 401/403/404 routing
- `.claude/cias-web/rules/realtime-websockets.md` — AnyCable channels

---

## Step 2.5 — Replicate locally (when the local setup allows)

Static reading tells you where the bug lives; **running it tells you whether your hypothesis is right**. If the bug is plausibly reproducible on the local setup, verify your assumptions by executing code — a hypothesis confirmed (or refuted) by execution beats paragraphs of speculation, and a refuted one sends you back to Step 2 *before* the analysis is written, which is exactly the point.

**Allowed — local only** (verify `Rails.env.development?` and a localhost DB before running anything):
- **Read-only DB inspection**: `bin/rails runner '<one-liner>'` from `cias-api/` — record counts, actual column values, the real state of a flow's rows (the fastest way to test "I think X is nil here").
- **Invoking the suspect service/job directly**: `bin/rails runner` with a script; wrap any mutation in a rolled-back transaction (`ActiveRecord::Base.transaction { …; raise ActiveRecord::Rollback }`). Call `perform_now` — never enqueue to a running Sidekiq.
- **A throwaway spec** when you need factory data: `cias-api/spec/tmp_triage/cias_<NNNN>_repro_spec.rb` reproducing the flow via FactoryBot, run with `bundle exec rspec` (test DB, auto-rolled-back), then **delete it before finishing** — it is diagnostic scaffolding, not the regression test (that's `/fix-bug`'s job).
- **Frontend**: run existing Jest/saga specs (`npm test -- <path>`) to confirm the current behavior of a suspect saga/component.
- If the harness shell resolves the wrong Ruby (check `ruby -v` against `cias-api/.ruby-version`), call `bundle` through your version manager's wrapper or shim (rvm: `~/.rvm/wrappers/ruby-<version>/bundle`; rbenv/asdf/mise: their shims) — the Claude shell may not load your shell profile.

**Safety non-negotiables** (bright lines for the executing agent — these are in addition to the harness's own sandbox and permission prompts; if a command is blocked or prompts, that's the system working — surface the ask honestly, never work around it):

- **Environment guard first, every session of Step 2.5** — run this before any other diagnostic and abort if it fails:
  ```bash
  bin/rails runner 'abort("NOT dev: #{Rails.env}") unless Rails.env.development?;
    h = ActiveRecord::Base.connection_db_config.configuration_hash[:host];
    abort("NOT localhost: #{h}") unless [nil, "localhost", "127.0.0.1"].include?(h);
    puts "safe: #{Rails.env} @ #{h || "local socket"}"'
  ```
  Never set `RAILS_ENV` to anything but development/test; never export or point at a remote `DATABASE_URL`.
- **Forbidden outright**: `db:drop` / `db:reset` / `db:schema:load` / `db:migrate` / `db:seed`; `update_all` / `delete_all` / `destroy_all` / raw `TRUNCATE`/`DELETE`/`UPDATE` SQL outside a rolled-back transaction; `bundle install` / `bundle update` or any gem/system-package change; `sudo`; starting or killing long-running processes (servers, Sidekiq, Postgres); deleting or editing any file except your own throwaway scripts under `spec/tmp_triage/` or the scratchpad.
- **Runner scripts are pure Ruby against the app** — no shelling out (`system`, backticks, `%x`, `exec`), no `FileUtils` outside the scratchpad, no network calls to third parties (Twilio / Epic / Google / CAT-MH — if the code path calls them, stop before the call or note it as untestable locally).
- **The dev DB is the developer's own working data — treat it as read-only.** Anything that writes belongs in the throwaway-spec route (test DB, disposable, auto-rollback); a rollback-wrapped write against dev is the exception, not the default.
- Real PHI never appears in test data, scripts, or command output.
- Shared/remote environments and DBs are off-limits, full stop.

**Skip honestly** when local can't reproduce it — missing integration env vars (Twilio / Epic / CAT-MH / Documo), prod-only data, scheduled infra — and **time-box the attempt**: if reproduction needs elaborate seeding, note what it would take and leave execution to `/fix-bug`. Either way, record the outcome — hypothesis **confirmed / refuted / untested** — with the exact command(s) run and what they showed; it feeds Steps 4 and 4.3.

---

## Step 3 — Log-visibility verdict

For **each** of the four log sources below, answer: would this bug actually leave a trace? What would you grep for?

| Source | What it captures |
|---|---|
| **LogRocket** | Frontend session replays, console errors, network calls (cias-web only). Sensitive fields auto-sanitized. |
| **Sentry** | Both frontend (React error boundary, `Sentry.captureException`) and backend exceptions (`ComplexException`, raised exceptions in controllers/services/jobs). Includes stack traces and breadcrumbs. |
| **Rails API logs** | HTTP request/response, controller-level errors, parameters (with filter_parameters applied), DB queries in dev. |
| **Sidekiq logs** | Background job lifecycle: enqueue, start, success, fail, retry, exhausted. Job class + args. |

For each source, evaluate honestly:
- **Visible**: yes / no / partial (e.g. "yes but PII is sanitized")
- **What to filter on**: error class, controller name, URL path, job class, user ID, time window
- **What you'll see** (or won't): the specific signal to look for
- **Confidence**: high / medium / low

If the bug would NOT leave a trace in **any** log source (silent failure — e.g. wrong-but-200 response, swallowed exception, no-op job), call it out explicitly. That's a missing-instrumentation gap and worth flagging for the fix.

Tips for common CIAS bug patterns:
- **Silent saga failures** in cias-web: errors are caught and dispatched as error actions; only show up in LogRocket as a failed network request + a toast event. Not in Sentry unless `Sentry.captureException` is explicitly called.
- **Sidekiq retries**: by default retry for 1h × `Settings.sidekiq.retries` attempts; final failure surfaces in Sentry only via `sidekiq_retries_exhausted` hooks (see `app/jobs/concerns/variable_references_lock_management.rb` for an example).
- **Lockbox-encrypted fields**: never appear in logs in plaintext — if the bug involves user/answer data, you can't grep for the actual value.
- **AnyCable WebSocket bugs**: not in standard Rails logs — separate AnyCable RPC logs.
- **Twilio inbound SMS bugs**: enter via `V1::TwilloMessageController` (controller; note the "Twillo" typo) and delegate to `V1::Sms::Replay` (service in `app/services/v1/sms/`). The HTTP request shows in Rails logs; service exceptions go to Sentry via `ExceptionHandler`.
- **Twilio outbound SMS bugs**: go through `Communication::Sms` (service). Often called from Sidekiq jobs — check Sidekiq logs first.
- **Translation / Google TTS failures**: caught in `V1::Google::TranslationService` and `Audio::TextToSpeech::Google` — usually re-raised, so Sentry catches them.

**Exceptions that the API explicitly does NOT send to Sentry** (per `app/controllers/concerns/exception_handler.rb`) — don't tell the user to check Sentry for these:
- `CanCan::AccessDenied` (403 forbidden)
- `ActiveRecord::RecordNotFound` (404)
- `JSON::ParserError`
- `EpicOnFhir::NotFound`, `EpicOnFhir::AuthenticationError`
- `CatMh::ConnectionFailedException`, `CatMh::ActionNotAvailable`
- `ConcurrentEditException`

These will only show up in Rails API logs. Conversely, `ActiveRecord::RecordInvalid`, `RecordNotUnique`, `RecordNotSaved`, `ParameterMissing`, `ArgumentError`, `Dentaku::Error`, `ComplexException`, `EpicOnFhir::UnexpectedError`, and `ActiveModel::ForbiddenAttributesError` **do** go to Sentry automatically.

**Environment caveat**: LogRocket and Sentry only fire when their env vars are configured. Local dev typically has neither — if the user can only reproduce locally, those sources are dead ends and you should say so.

---

## Step 4 — Write conclusions

Save the analysis to `.claude/jira-tasks/cias-<NNNN>-<slug>/log-analysis.md`:

```markdown
---
key: CIAS-NNNN
analyzed: <today's date>
verdict: <one-line summary, e.g. "Backend Sidekiq job — visible in Sidekiq + Sentry">
---

# CIAS-NNNN — Log Analysis

## Reproduction hypothesis

<one paragraph: what you think is happening, based on the ticket + code reading>

**Local replication (Step 2.5)**: confirmed ✓ | refuted → revised | untested — <one line: what was executed and what it showed, or why it was skipped>

## Affected area

- **Repo(s)**: cias-api | cias-web | both
- **Primary file(s)**: `<absolute or repo-relative paths to the suspect code>`
- **Trigger**: <user action / cron / webhook / WS event>
- **Job class** (if Sidekiq): `<ClassName>` on queue `<queue>`

## Where to look

### LogRocket
- **Visible**: yes / no / partial
- **Filter**: <user ID, session URL, time range, console message>
- **Signal**: <what you'll see — error toast, failed network call, etc.>
- **Confidence**: high / medium / low

### Sentry
- **Visible**: yes / no / partial
- **Project**: cias-api | cias-web
- **Filter**: <error class, controller, transaction>
- **Signal**: <stack trace location, error message pattern>
- **Confidence**: high / medium / low

### Rails API logs
- **Visible**: yes / no / partial
- **Endpoint(s)**: `<METHOD /v1/...>`
- **Grep**: `<pattern>`
- **Confidence**: high / medium / low

### Sidekiq logs
- **Visible**: yes / no / partial
- **Job**: `<ClassName>` (queue: `<queue>`)
- **Grep**: `<pattern, e.g. job ID, user ID>`
- **Confidence**: high / medium / low

## Instrumentation gaps

<list anything that should be logged but isn't, or PII-sanitized fields that hide the real value>

## Next steps

- <2–4 concrete actions: e.g. "pull the user's LogRocket session at 14:32 UTC", "grep Sentry for `Api::Hfhs::AuthenticationError` in the last 7d", "reproduce locally with `rails c` + `MyJob.perform_now(user_id)`">
```

---

## Step 4.3 — Write the reproduction scenarios

Turn the reproduction hypothesis into **executable scenarios** at `<dir>/reproduction.md` — two paths: through the web UI, and directly against the backend. These are what the developer runs first, and what `/fix-bug` turns into the failing test. Every route, path, model, service, and job signature you name must be **verified against the code** (you just located it in Step 2) — mark anything you couldn't verify as `(unverified)`.

```markdown
---
key: CIAS-NNNN
created: <today's date>
verified-against-code: yes | partial
verified-by-execution: yes | partial | no   # Step 2.5 outcome — mark each scenario below as "executed locally ✓" or "untested"
---

# CIAS-NNNN — Reproduction scenarios

## Preconditions
- **Environment**: <local dev / test.cias.app — note if the bug needs LogRocket/Sentry env vars, cron, or Sidekiq running>
- **Data**: <what must exist — intervention/session state, published status, SMS plan, etc.; seeding hints>
- **User/role**: <e.g. participant with access to session X; researcher owning the intervention>

## A — Web UI
1. Log in as <role>.
2. Navigate to <route/path in the SPA>.
3. <action — click/fill/submit, concrete values>
...
- **Expected**: <correct behavior>
- **Actual (bug)**: <the observable symptom — error toast, wrong value, nothing happens>
<note time/state dependencies — e.g. "only after the daily SMS dispatch", "only on a published intervention">

## B — Backend (Rails)
From `cias-api/`:
```ruby
# rails console
user = User.find_by(email: '<seeded user>')
# minimal setup …
V1::SomeService.call(<verified signature>)
# → observe: <exception class / wrong return value / silent no-op>
```
or over HTTP:
```bash
curl -X <METHOD> '<host>/v1/<verified route>' -H 'Access-Token: …' -H 'Uid: …' -H 'Client: …' -d '<payload>'
# → observe: <status / body>
```
- **Observe**: <the exact wrong output that proves the bug — this is what the failing test will assert on>

## Caveats
<unverified assumptions · Lockbox-encrypted values you can't grep/inspect · anything only reproducible with production data>
```

Rules for this file: **non-destructive** commands only (no `destroy`/`update_all`/state mutation on shared environments — prefer local dev, and say when local can't reproduce it); **never include real PHI or credentials** — placeholder emails/tokens only; if one of the two paths can't reproduce the bug (e.g. backend-only race, UI-only rendering issue), say so explicitly rather than inventing steps.

---

## Step 4.5 — Verify the triage (one fresh agent; sanity check)

A wrong triage misdirects the whole debugging session — verify before handing it to the developer. Spawn one fresh `general-purpose` agent:

> You are the TRIAGE VERIFIER. Working directory: `<dir>` (relative to the workspace root, your cwd).
> Read `ticket.md`, `log-analysis.md`, and `reproduction.md`, then verify the checks below against
> the actual code (Read/Grep/Glob in `cias-api/`, `cias-web/`). Write `<dir>/triage-verification.md`:
> each check as PASS or FAIL with evidence. Do not edit any other file. Return a ≤4-line summary plus a `Pills consulted:` line.
>
> Checks:
> 1. **References** — every file, class, route, saga, and job the analysis names exists at the stated path (or is honestly marked as a guess).
> 2. **Sentry routing** — visibility claims are consistent with `cias-api/app/controllers/concerns/exception_handler.rb` (the not-sent-to-Sentry list) and, for frontend claims, the Sentry/LogRocket setup in `.claude/cias-web/rules/error-handling-and-monitoring.md`.
> 3. **Endpoint claims** — named endpoints exist in `cias-api/config/routes.rb`.
> 4. **Sidekiq claims** — job class and queue names are real.
> 5. **Hypothesis consistency** — the reproduction hypothesis contradicts neither the ticket's symptoms nor the cited code.
> 6. **Reproduction scenarios** — the Web-UI steps use routes/screens that exist (check the SPA routes and role guards), the Rails commands use real classes with matching method signatures and correct console/curl syntax, the steps are consistent with the hypothesis, and everything is non-destructive and PHI-free.

Then **you** fix every FAIL directly in `log-analysis.md` / `reproduction.md` (you authored them minutes ago — mechanical corrections), record them in `triage-verification.md` under `## Fixes applied`, and re-verify the affected checks yourself. **One round only** — anything not mechanically fixable becomes an open question for the developer, stated in the summary.

---

## Step 4.6 — Write the developer summary

Distill the verified triage into `<dir>/summary.md` — a gut-check the developer reads in ~1 minute and can correct immediately, without opening `log-analysis.md`. **Hard cap: ≤ 25 lines.** Every bullet must be falsifiable and traceable to the analysis — no new information.

```markdown
---
key: CIAS-NNNN
status: triaged
verdict: <the one-liner from log-analysis frontmatter>
---

# <CIAS-NNNN> — <slug>: triage summary

**Symptom** — <1–2 sentences from the ticket.>

## Core claims — tick or correct
- [ ] Affected: <repo · module · primary file(s)>
- [ ] Trigger: <user action / cron / webhook / WS event>
- [ ] Hypothesis: <one sentence — what you think is happening>
- [ ] Look first: <primary log source + the exact filter>
- [ ] Repro: <one line — the fastest path, e.g. "UI: <3-word path>" or "`V1::SomeService.call(...)` in rails c"> <(reproduced locally ✓ | untested)>
<≤ 5 bullets — only claims that would redirect debugging if wrong>

## Instrumentation gaps
<one line, or "none">

## Next steps
<2–4 concrete actions>

_Full detail: `log-analysis.md` · repro: `reproduction.md` · checks: `triage-verification.md`_
_Pills consulted: <title (source)> · … — or none — <why>_
```

Then flip `ticket.md` frontmatter `status: triaging → triaged`.

---

## Step 4.7 — Pill feedback (byproduct)

If Steps 2–3 (or the verifier) caught a pill contradicting the code (**drift**), a subsystem no pill covers (**gap**), or a verified non-obvious fact worth a pill (**new-knowledge**): append entries to `<dir>/pill-feedback.md` — same strict format as the new-feature pipeline (`type` / `pill` (Interlay title) / `repo` / `evidence` / `suggested change` / `found-by: triager | verifier`) — then harvest them into `.claude/knowledge-pills/_inbox/` as pending-review drafts per `.claude/skills/new-feature/SKILL.md` Step 5.5 (same dedupe rules; never create or edit an Interlay pill). An empty file is a normal outcome.

---

## Step 5 — Report back

Send the user a **short** summary (4–6 lines max):

1. Which repo / module the bug likely lives in.
2. **Primary** log source to check first, with the specific filter to use.
3. Verification outcome in one line: `5/5 checks PASS` or `<n> FAILs fixed — see triage-verification.md`, plus any open question the verifier couldn't settle.
4. Any **clarifying question** that would meaningfully change the analysis (max 1 — only ask if blocking).
5. **Point to `summary.md` first**: "start with `<dir>/summary.md` — tick or correct the claims." Then the artifact set: `ticket.md`, `log-analysis.md`, `reproduction.md`, `triage-verification.md`, `interlay-context.md`, `pill-feedback.md` (if any).
6. Knowledge upkeep, one line: the `Pills consulted:` line (see the reporting section at the end), whether the Interlay snapshot was taken, and `<n>` pill-feedback drafts harvested to `.claude/knowledge-pills/_inbox/` (or "none"; if n > 0, remind `/pills-sync`).

End with: "Review `summary.md` — if a claim is wrong, tell me and I'll re-triage that part. When the hypothesis holds, run `/fix-bug <key>` (here or in a fresh session) to plan and implement the fix."

---

## Hard rules

- **Always create the dir and ticket.md first** — even if analysis is shallow. The user wants the ticket captured before any analysis runs.
- **Verify file paths** before naming them in `log-analysis.md`. Use Read/Grep/Glob. Don't invent class names.
- **No fix code** in this flow. If you find an obvious one-liner, mention it in "Next steps" but do not edit code. The fix belongs to `/fix-bug`, after the developer confirms the hypothesis. Throwaway diagnostics from Step 2.5 (runner scripts, `spec/tmp_triage/` specs) are fine — but delete them before the report; the repos must be left untouched.
- **Be honest about uncertainty**. Confidence: low is a valid answer. Saying "I don't think this leaves any trace" is more useful than guessing.
- **Don't duplicate the ticket body** into `log-analysis.md` — that's what `ticket.md` is for.
- **Interlay never blocks** — the Step 1.5 snapshot must never block or fail a triage; on any MCP error, triage from the rules + code and say so.
- **Never skip Step 4.5 verification**, and never report the triage as done while a FAIL is unfixed and undisclosed. One verification round only.
- **Pill feedback is a byproduct** — evidence-backed entries only; drafts to `_inbox/`; never create or edit an Interlay pill from this flow.
- **Reproduction scenarios are executable claims** — verify every route/class/signature they name, keep the commands non-destructive, never include real PHI or credentials, and say honestly when a path (UI or backend) cannot reproduce the bug instead of inventing steps. **Local execution (Step 2.5) is encouraged** — an executed scenario is worth more than a theorized one; shared/remote environments are strictly off-limits from this flow.

---

## Knowledge-pill reporting (always)

Say which knowledge pills this run actually relied on, so the developer can judge what it was grounded in:

- **Mid-steps** — every progress update for a step that read pills names them, e.g. `Step 2 — pills: Participant Session Flow Engine, Dentaku Formula Evaluation Engine`. When you hand pills to a subagent (a snapshot file, or titles in its prompt), say which.
- **Final output** — the final summary/report ends with one line:
  `Pills consulted: <title> (<source>) · <title> (<source>) …`
  where `<source>` is where you read it: `Interlay`, `snapshot` (an `interlay-context.md` / `.pills.md` file) or the local file path. Fold in the pills your subagents report and mark them (`… (Interlay, via auditor)`). This line comes on top of any line cap a report section sets.
- No pills used → `Pills consulted: none — <why>` (e.g. "dependency bump, no domain logic", "Interlay unavailable").
- List only pills actually read in this run — never ones merely named in an index or table.
