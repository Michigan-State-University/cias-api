# CIAS Workspace — Claude Instructions

This is a two-repo workspace for the **CIAS 3.0** platform (Computerized Intervention Authoring System — Michigan State University). The two repositories live side-by-side here and are usually worked on together.

```
CIAS/                    # workspace root — start `claude` here
├── cias-api/            # Rails 7 / Ruby 3.3 backend, JSON:API      (own git repo)
├── cias-web/            # React 17 + TypeScript SPA                 (own git repo)
├── CLAUDE.md            # this file
├── .mcp.json            # project MCP servers (context7)
└── .claude/
    ├── commands/ agents/ skills/ hooks/ settings.json   # shared team setup
    ├── cias-api/        # backend rules (+ your local plans, notes)
    ├── cias-web/        # frontend rules + knowledge (+ your local plans, notes)
    ├── knowledge-pills/_inbox/   # local DRAFT pill updates — never load as knowledge
    └── jira-tasks/      # local per-ticket workdirs created by /new-bug, /new-feature, …
```

Each sub-repo is a **separate git repository** — `git` commands run from inside `cias-api/` or `cias-web/`, not from this workspace root.

The shared part of this setup is maintained in `cias-api/.claude-setup/` — see its README for install/update. Everything else under `.claude/` (jira-tasks, plans, notes, `settings.local.json`) is **local to your machine** and must never be committed: both repos are **public on GitHub**.

---

## ⭐ Knowledge pills — consult FIRST, before searching code

CIAS knowledge pills are curated, citation-backed deep-dives on every major subsystem. They live in **Interlay** (the HTD knowledge base, `mcp__claude_ai_Interlay__*` tools — project **CIAS**, directories `cias-api` and `cias-web`). **They are the source of truth for understanding this project and the first place to look for any information-gathering task.**

**The rule for every prompt:** when you need to understand how something in CIAS works — a model, a flow, a convention, a wire format — **fetch the relevant pill before grepping or reading source files.** The pill is usually enough; it summarizes the subsystem and cites the exact files (`(src: …)`) if you do need to go deeper. Only drop to the code when the pill genuinely lacks the specific detail you need (an exact edge case, a value not tabulated, recently changed code).

How to fetch:
- Call `mcp__claude_ai_Interlay__get_interlay_context` with a prompt that names the pill title(s) from the tables below **plus** what you need to know, e.g. `"Participant Session Flow Engine: how an answer leads to the next question"`. The search is semantic and returns full pill bodies grouped by scope (project → organization → global) — follow the `<knowledge_priority_rule>` it returns.
- One call can return several pills; make another call if a pill you need didn't come back.
- If a pill and the code disagree, the **code wins** — note the drift (see `/pills-sync`).
- If Interlay is unavailable (connector not enabled, MCP error), say so once and fall back to `.claude/<repo>/rules/` + the code. Never block on it.
- Pill updates go through `.claude/knowledge-pills/_inbox/` drafts and `/pills-sync` — never write pills ad hoc.
- **Always say which pills you used.** Every command, skill and agent names the pills a step read in its progress update for that step, and ends its final summary with `Pills consulted: <title> (<source>) · …` — source `Interlay`, `snapshot` or a file path — or `Pills consulted: none — <why>`. Ad-hoc answers that leaned on a pill end with the same line.

### Backend pills (Interlay directory `cias-api`)

| Pill title | Load when working on… |
|---|---|
| Intervention Content Hierarchy and STI | Intervention → Session → QuestionGroup → Question tree; Rails STI shape |
| Question–Answer Parallel STI and Body Schema | Question/Answer models, new question type, body validation/encryption boundary |
| Participant Session Flow Engine | Answer → next-question pipeline (AnswerService/FlowService/NextQuestion/Branching/Schedule/Reflection) |
| Dentaku Formula Evaluation Engine | Formula evaluation — branching, SMS variant, report section selection |
| Chart Statistics Collection and Aggregation | ChartStatistic creation on finish + bar/pie/percentage aggregation |
| Dashboard Charts and Analytics | ReportingDashboard → Section → Chart structure, chart `formula` JSON, chart data endpoint |
| Report Template PDF Generation and Sharing | PDF reports at finish — template/section/variant, WickedPdf, GeneratedReport, email/fax delivery |
| SMS Plan Scheduling and Variant Dispatch | Outbound post-session SMS — plan config, finish trigger, variant content, Sidekiq → Twilio |
| Session::Sms — Bidirectional SMS Campaign Flow | SMS-as-session channel — keyword reg, daily dispatch, inbound replies, finish |
| TLFB (Timeline Follow-Back) Assessment Module | TLFB assessment — question subtree, runtime tables, calendar/event/result CRUD |
| CAT-MH Adaptive Assessment Integration | CAT-MH integration — `Api::CatMh`, interview lifecycle, Session/UserSession::CatMh, `cat_mh_*` tables |
| Epic on FHIR and Henry Ford Health System (HFHS) Integration | Epic on FHIR / HFHS — auth, patient verify, appointments, HL7 v2.5, HfhsPatientDetail, `henry_ford` routes |
| ActionCable Real-Time Channels | WebSockets — live chat, collaborative editing, navigator presence |
| Multilanguage Translation and TTS Audio | Translation, narrator TTS, audio caching, Google Translate/TTS |
| Organization → HealthSystem → HealthClinic Hierarchy and Invitations | Org→HealthSystem→Clinic tier, admin invites, `organizable` polymorphism, soft-delete propagation |
| PHI Encryption and Audit Gem Split | Storing PHI/PII; choosing between `audited` and `has_paper_trail` |
| V1 Auth and Authorization Layering | Adding an endpoint/controller/route; debugging 401/403 |
| V1 Serializer — JSON:API Response Convention | Writing/modifying a V1 serializer; import/export pipeline |
| RSpec Test Suite Conventions | Writing/reviewing specs; endpoint/ability/service specs; slow or failing CI |

### Frontend pills (Interlay directory `cias-web`)

| Pill title | Load when working on… |
|---|---|
| CIAS Redux Slice State Shape | Adding/modifying a Redux slice under `app/global/reducers/` |
| CIAS Redux Action-Type Constants Convention | Redux action types — constants, reducers, sagas, action creators |
| CIAS Redux Injector Descriptor Objects | Lazy reducer/saga injection; wiring a slice into a container |
| CIAS Saga Naming Conventions | Writing/renaming/reviewing a redux-saga generator |
| Selector Naming Convention | Writing/reading/debugging a Redux selector |
| CIAS JSON:API Normalization Pipeline | How sagas deserialize JSON:API into plain JS for Redux |
| CIAS Frontend Model Typing Conventions | Adding/modifying a TS domain model in `app/models/` |
| CIAS Question/Answer Polymorphic Type System | Question/answer type narrowing, new type, STI class name → TS |
| Formula / Branching / Randomization Model | Conditional branching, randomization, `Formula`/`Pattern`/`Target` structures |
| Narrator Block & Animation Model | Animated narrator — block sequences, animation types, voice/animation settings |
| TLFB Calendar Redux Subsystem | TLFB frontend — 3 question types flow, Calendar/Day/Event model, tlfb slice optimistic cache |
| CIAS AnyCable Channel Subscription Pattern | Real-time WS — new channel, server push → Redux, outbound `perform()` |
| Devise-Token-Auth Header Pipeline | Auth state, HTTP request setup, WebSocket connection init |
| CIAS Client-Side Route RBAC Guard | Client-side route access — role gates, unauth redirects, public-only pages |

New pills may exist in Interlay before this table is updated — the semantic search finds them anyway.

---

## Pick the right context

Most tasks land squarely in one repo. Load the matching sub-instructions before doing real work:

- **Backend / Rails / API / Sidekiq / Postgres / encryption** → @.claude/cias-api/CLAUDE.md
- **Frontend / React / Redux / Saga / UI / styled-components / i18n** → @.claude/cias-web/CLAUDE.md

Each sub-CLAUDE.md imports its own deep-dive rule files from `.claude/<repo>/rules/`. Read the relevant rule file before editing that subsystem.

### Full-stack tasks (touching both)

A "new feature" typically means: add endpoint + serializer in `cias-api`, add Redux module (constants/actions/types/reducer/selectors/sagas) + container in `cias-web`. Coordinate the contract via:
- API path convention: `/v1/<resource>` returning JSON:API
- Frontend consumes via `axios` inside a saga, normalized through `jsonApiToArray` / `jsonApiToObject`
- Auth via `Access-Token` / `Uid` / `Client` headers (15-min token lifespan, rotates per request)

When you make an API change, check the matching frontend consumer in `cias-web/app/global/reducers/` and `cias-web/app/containers/` — these are not regenerated, they're hand-written sagas with hardcoded URLs.

---

## How to run things

| Repo | Dev command | Default port |
|---|---|---|
| `cias-api` | `bundle install && rails db:migrate && rails s` | `:3000` |
| `cias-web` | `nvm use && npm install && npm start` (Node 22) | `:4200` |

Test commands:
- API: `bundle exec rspec`, `bundle exec rubocop`
- Web: `npm test`, `npm run lint`, `npm run lint:css`, `npx tsc --noEmit` (the prod build does **not** type-check), `npm run e2e` (Playwright), `npm run cypress:open`

---

## Team rules

- **Both repos are public (GPL-3).** Never commit secrets, PHI, client names/notes, or unfixed security findings — not in code, specs, fixtures, commit messages or PR descriptions. Workspace notes stay in the gitignored `.claude/` folders.
- **No ticket numbers in code.** Jira keys (`CIAS-4191`) and task-doc labels ("Set 2") never go in filenames, class/module names, constants or spec `describe` strings — name things after the behaviour they cover. A ticket key in a **comment** is fine.
- **Don't touch `.github/workflows/code-quality.yml`** (the HTD code-quality / SonarQube scan) in either repo, even in "bump all actions" sweeps — mention any issue in it instead.
- **Dependency bumps: read every changelog.** Never call a bump safe from the semver level + green tests; read the release notes for every package and version in the range, and say which sources you read. Use `/bump-gems` and `/bump-npm-packages`.
- **`@anycable/web` ≥ 0.4 is blocked** (Dependabot keeps proposing it): cias-api channels can send a duplicate `confirm_subscription`, which AnyCable 1.x answers with `unsubscribe` → `InterventionChannel#unsubscribed` drops the edit lock and stops streams. Don't merge it until the backend sends confirmation exactly once.
- **The workflow commands stop before committing** — the developer reviews the diff and commits/pushes/opens PRs themselves.

---

## Workspace conventions

- **Per-ticket workdirs** live under `.claude/jira-tasks/cias-<NNNN>-<slug>/` (created by `/new-bug`, `/new-feature`, `/new-estimate`). Local only.
- **Plans, RFCs, exploration notes** go under `.claude/<repo>/plans/`; repo-specific Jira scratchpads under `.claude/<repo>/jira-tasks/`. Local only.
- **Debugging artifacts** (backlog notes, DB queries, manual-test scripts, scan reports) go under purpose-named dirs in `.claude/<repo>/` (`backlog/`, `queries/`, `testing/`, `scan-reports/`, `notes/`). Local only — they often reference production data or open security issues.
- **Subsystem rules** live under `.claude/<repo>/rules/` and are loaded by the sub-CLAUDE.md. These are shared — change them in `cias-api/.claude-setup/` and open a PR.

When creating a new plan or note, drop it in the relevant `.claude/<repo>/plans/` (or jira-tasks/notes) — don't scatter them at workspace root.

### Branching, PRs & merges

The promotion flow (`feature → dev → test → master`), dated integration branches (`dev_to_test_<date>` / `test_to_master_<date>`), deploy remotes, and hotfix back-porting are documented in [git-and-merge-strategy.md](.claude/git-and-merge-strategy.md). Read it before doing release/hotfix/merge work.

### Bug triage flow

Use `/new-bug` with the pasted Jira ticket as the argument. It will:
1. Create `.claude/jira-tasks/cias-<NNNN>-<slug>/`
2. Save `ticket.md` verbatim (+ an Interlay knowledge snapshot)
3. Locate the affected code in `cias-api`/`cias-web` (knowledge pills first)
4. Produce `log-analysis.md` covering LogRocket / Sentry / Rails API / Sidekiq visibility, plus `reproduction.md` — executable repro scenarios via the web UI and via backend Rails commands (verified, non-destructive, PHI-free)
5. Verify the analysis + repro steps with a fresh agent (`triage-verification.md`) and distill a ≤25-line `summary.md` (tick-or-correct claims) for a 1-minute developer review

Definition: `.claude/commands/new-bug.md`. Fixing is a separate step — after the developer confirms `summary.md`, `/fix-bug CIAS-NNNN` proves the root cause with a failing test, applies the minimal fix + regression test, and hands the diff over without committing. Status flow in `ticket.md`: `triaging → triaged → fix-in-progress → fixed`.

### Feature flow

`/new-estimate` (a number only) or `/new-feature` (plan + estimate, adversarially audited) → review `summary.md` → `/run-auditors` (if recommended) → `/create-phases` → `/implement-phase` once per phase, ideally in a fresh session. QA: `/qa-scenarios-creator` → `/qa-run`.

---

## Quick tech stack reference

**cias-api** — Rails 7.2, PG (UUID PKs), Sidekiq (ActiveJob), Devise + DeviseTokenAuth (Argon2), CanCanCan, Lockbox encryption + blind_index, Paper Trail + Audited, jsonapi-serializer, AASM, AnyCable. Integrations: Twilio (SMS), Google TTS / Translation, Henry Ford HL7, Epic on FHIR, CAT-MH, Documo (fax), AWS S3.

**cias-web** — React 17, TypeScript 5.7, Redux 4, Redux Saga 1.3, Reselect, Immer, typesafe-actions, Styled Components 5, React Intl 6, Formik + Yup, axios + axios-retry, json-api-normalizer, AnyCable WebSockets, Lottie (Peedy narrator), react-flow-renderer, react-beautiful-dnd / @dnd-kit, Jest 29 + RTL, Cypress 13 + Playwright, ESLint (Airbnb + TS).

Domain shorthand: **Intervention → Session → QuestionGroup → Question → Answer**, plus SMS plans, TLFB calendar assessments, and a HealthSystem/HealthClinic org hierarchy. See [domain_model](.claude/cias-api/rules/domain_model.md) / [domain-model](.claude/cias-web/rules/domain-model.md) for full hierarchy.
