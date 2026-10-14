# Knowledge-pill selection index

Knowledge pills live in **Interlay** (project CIAS, directories `cias-api` / `cias-web`). Consult them **before** grepping source: they are the source of truth for how each CIAS subsystem works and cite the exact files (`(src: …)`) when you need to go deeper. Read the pill, then drop to code only to confirm specific touchpoints. If a pill and the code disagree, **the code wins** — note the drift.

**How to get a pill:** first check `<WORKDIR>/interlay-context.md` — the orchestrator stores the pills it fetched there. If a pill you need isn't in it, call `mcp__claude_ai_Interlay__get_interlay_context` with a prompt naming the pill title(s) below plus your question (e.g. `"Dentaku Formula Evaluation Engine: how SMS variant formulas are matched"`). The search is semantic and returns full pill bodies. If the tool is unavailable, say so in your output and size from `.claude/<repo>/rules/` + the code.

Load **every** pill the feature plausibly touches. A full-stack feature usually needs one or two backend pills **and** one or two frontend pills.

## Backend pills (Interlay directory `cias-api`)

| Pill title | Load when the feature touches… |
|---|---|
| Intervention Content Hierarchy and STI | Intervention → Session → QuestionGroup → Question tree; STI shape |
| Question–Answer Parallel STI and Body Schema | Question/Answer models, a new question type, body validation/encryption |
| Participant Session Flow Engine | Answer → next-question pipeline (Answer/Flow/NextQuestion/Branching/Schedule) |
| Dentaku Formula Evaluation Engine | Formula evaluation — branching, SMS variant, report selection |
| Chart Statistics Collection and Aggregation | ChartStatistic creation on finish, bar/pie/percentage aggregation |
| Dashboard Charts and Analytics | ReportingDashboard → Section → Chart, chart `formula` JSON, chart data endpoint |
| Report Template PDF Generation and Sharing | PDF reports at finish — template/section/variant, WickedPdf, delivery |
| SMS Plan Scheduling and Variant Dispatch | Outbound post-session SMS — plan config, finish trigger, variant, Sidekiq → Twilio |
| Session::Sms — Bidirectional SMS Campaign Flow | SMS-as-session channel — keyword reg, daily dispatch, inbound replies |
| TLFB (Timeline Follow-Back) Assessment Module | TLFB assessment — subtree, runtime tables, calendar/event/result CRUD |
| CAT-MH Adaptive Assessment Integration | CAT-MH integration — interview lifecycle, `cat_mh_*` tables |
| Epic on FHIR and Henry Ford Health System (HFHS) Integration | Epic on FHIR / HFHS — auth, patient verify, appointments, HL7 v2.5 |
| ActionCable Real-Time Channels | WebSockets — live chat, collaborative editing, navigator presence |
| Multilanguage Translation and TTS Audio | Translation, narrator TTS, audio caching |
| Organization → HealthSystem → HealthClinic Hierarchy and Invitations | Org→HealthSystem→Clinic tier, admin invites, soft-delete propagation |
| PHI Encryption and Audit Gem Split | Storing PHI/PII; choosing `audited` vs `has_paper_trail` |
| V1 Auth and Authorization Layering | Any new endpoint/controller/route; roles & abilities |
| V1 Serializer — JSON:API Response Convention | Any new/changed V1 serializer; import/export |
| RSpec Test Suite Conventions | Always — sizing the backend test work |

## Frontend pills (Interlay directory `cias-web`)

| Pill title | Load when the feature touches… |
|---|---|
| CIAS Redux Slice State Shape | A new/modified Redux slice |
| CIAS Redux Action-Type Constants Convention | Redux action types (constants/reducers/sagas/creators) |
| CIAS Redux Injector Descriptor Objects | Lazy reducer/saga injection; wiring a slice into a container |
| CIAS Saga Naming Conventions | Any new redux-saga generator |
| Selector Naming Convention | Any new selector |
| CIAS JSON:API Normalization Pipeline | How sagas deserialize JSON:API into Redux |
| CIAS Frontend Model Typing Conventions | A new/changed TS domain model in `app/models/` |
| CIAS Question/Answer Polymorphic Type System | Question/answer type narrowing, a new type |
| Formula / Branching / Randomization Model | Conditional branching, randomization UIs |
| Narrator Block & Animation Model | Animated narrator — blocks, animations, voice |
| TLFB Calendar Redux Subsystem | TLFB frontend — calendar/day/event, tlfb slice |
| CIAS AnyCable Channel Subscription Pattern | New WS channel; server push → Redux |
| Devise-Token-Auth Header Pipeline | Auth state, request setup, WS connection |
| CIAS Client-Side Route RBAC Guard | Client-side route access — role gates, redirects |

## Subsystem rule files (stack-specific behavior, for sizing)

- `.claude/cias-api/rules/` — `api_controllers.md`, `auth_roles.md`, `service_objects.md`, `sidekiq.md`, `database_patterns.md`, `encryption_security.md`, `integrations.md`
- `.claude/cias-web/rules/` — `api-and-auth.md`, `user-roles-and-routing.md`, `realtime-websockets.md`, `error-handling-and-monitoring.md`, plus the subsystem rule matching the UI
