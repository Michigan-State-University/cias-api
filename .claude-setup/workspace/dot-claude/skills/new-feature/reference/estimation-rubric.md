# Estimation rubric — CIAS new-feature

Shared calibration used by both the **planner** (to produce the estimate) and the **auditor** (to check it). Keeping one rubric makes estimates consistent run-to-run.

## Persona & unit

- Estimate for a **mid-level fullstack developer already familiar with this codebase**.
- The unit is the **ideal effort-day** = one focused engineering day (~6 productive hours).
- Convert to calendar time only in the final note: focus factor ~0.7 → calendar ≈ effort-days × 1.4. Call this out, don't bury it.

## Two estimates are required

Produce **two** effort estimates for the *same* developer:

1. **Traditional** — hand-written code, no AI assistance. This is the baseline; the anchors below are calibrated for it.
2. **AI-assisted** — the same developer working with Claude Code / agentic coding (prompting, reviewing, iterating on AI output).

Size every work item in **traditional** effort first, then derive the AI-assisted number by applying the per-category acceleration factors in the *"AI-assisted estimate"* section. **Do not apply a single flat multiplier** — acceleration varies sharply by task type, and some work barely speeds up at all.

## Method (traditional baseline)

Size each work item using the anchors below, then roll up by category. Anchors are *typical* values for this codebase — adjust **up** for novelty, external APIs, large-table or encrypted-column migrations, or unclear requirements; adjust **down** for copy-paste-of-an-existing-pattern work.

### Backend (cias-api) anchors — effort-days

| Work item | Typical |
|---|---|
| Simple migration (add column/index, small backfill) | 0.25–0.5 |
| Migration on a large/encrypted table or non-trivial backfill | 0.5–1.5 |
| New model (validations, associations, AASM if stateful) | 0.5–1 |
| New endpoint on an existing model (action + route + strong params) | 0.25–0.5 |
| New serializer / serializer change | 0.1–0.25 |
| CanCanCan ability rule(s) for a new resource | 0.25–0.5 |
| Service / query object (moderate business logic) | 0.5–1.5 |
| Sidekiq job (+ scheduling/retry handling) | 0.25–0.75 |
| New third-party integration touchpoint (auth, error handling, mapping) | 1–3 |
| New question/answer STI type (+ body schema + validation) | 1–2 |

### Frontend (cias-web) anchors — effort-days

| Work item | Typical |
|---|---|
| New Redux module (6-file pattern) + injector wiring | 0.5–1 |
| API-consumer saga (call + JSON:API normalize + error/toast) | 0.25–0.5 |
| New domain model in `app/models/` + types | 0.1–0.25 |
| Reusable stateless component | 0.25–0.75 |
| Page-level container wired to Redux | 1–2 |
| Form (Formik + Yup + i18n) | 0.5–1 |
| New route + RBAC guard | 0.1–0.25 |
| i18n messages + translation entries | 0.1–0.25 |
| Specialized UI (drag-drop / react-flow / narrator / charts / WS consumer) | 2–5 |

## Tests — count explicitly, never folded into impl

- **Backend RSpec** ≈ **40–60%** of backend impl effort (request + model/service + ability specs; factory updates).
- **Frontend tests** ≈ **30–50%** of frontend impl effort (component tests: console-error + snapshot + behavior; saga tests via redux-saga-test-plan).

## Manual / QA — count explicitly

- ≈ **15–25%** of total dev effort, **floor 0.5 day**.
- Push toward the high end when: multiple roles must be tested, there's a data migration to verify, the UI is cross-browser-sensitive, or it touches money / PHI / SMS-delivery (high blast radius).

## Overheads

- **Code review & PR iteration:** ≈ 10–15% of dev effort.
- **Contingency / risk:** 15% for a well-understood feature reusing existing patterns; up to 30% for new integrations, unclear requirements, or large-table migrations. The chosen % must be justified from the listed risks/assumptions.

## AI-assisted estimate (Claude Code / agentic coding)

Same developer, now using an agentic coding assistant. **Acceleration is per-task-type, not a flat multiplier** — and several categories barely move. Take each traditional line item and multiply by its **retained-effort factor** (AI-assisted ÷ traditional; lower = faster):

| Work category | Retained effort | ≈ speedup | Why |
|---|---|---|---|
| **Scaffolding / pattern replication** — Redux 6-file module, serializer, CRUD endpoint, simple migration, model, TS types, i18n messages, factories, test scaffolding | **0.30–0.45** | ~2.2–3.3× | Strong existing patterns in this codebase; the agent pattern-matches well and the dev mostly reviews. |
| **Standard logic** — service/query objects, sagas, Formik+Yup forms, moderate components, ability rules | **0.45–0.65** | ~1.5–2.2× | Agent drafts; dev corrects edge cases and wiring. |
| **Novel / complex / integration / judgment** — external APIs (HFHS HL7, Epic FHIR, CAT-MH, Twilio), tricky formula/branching, new question-type semantics, architecture, hard debugging | **0.70–0.90** | ~1.1–1.4× | Domain reasoning, external contracts, and correctness judgment stay with the human; AI rework risk is higher. |
| **Automated tests** | **0.40–0.60** | ~1.7–2.5× | AI generates cases/scaffolding fast — but the dev must still verify the tests are *meaningful*, not just green. |
| **Manual / QA testing** | **0.80–0.95** | ~1.05–1.25× | A human still clicks through every role/flow. AI helps draft checklists/scripts; it does not remove the testing. |
| **Code review & PR iteration** | **0.90–1.10** | ~flat | The dev now reviews AI-generated code instead of writing it — real time, and easy to under-count. Claim **no** savings here; it can even rise. |

Rules for the AI-assisted column:
- Apply the factor **per line item / category**, then roll up — never one global multiplier.
- **Contingency**: keep the same % or slightly higher for novel work (hallucination/rework variance); slightly lower is acceptable for pure-boilerplate features. Justify it.
- **Reality check**: a typical full-stack CIAS feature (lots of boilerplate + some real logic + QA that doesn't speed up) lands around **0.5–0.65× of traditional total (~1.5–2× overall)**. Be skeptical of any blended result faster than ~3× — that almost always means QA or review got silently cut, or novel work was mis-tiered as scaffolding. Flag and re-check.
- **Assumes**: the dev is proficient with Claude Code (effective prompting, disciplined review) and the work reuses the codebase's established patterns (CIAS has strong ones — a genuine tailwind). State this assumption.
- AI does **not** reduce: requirement clarification, design decisions, human review, manual QA, or stakeholder coordination. The AI-assisted total is never below the sum of these human-bound floors.

## Roll-up table (required shape — both estimates side by side)

| Category | Traditional (days) | AI-assisted (days) | Retained factor |
|---|---|---|---|
| Backend implementation | | | |
| Frontend implementation | | | |
| Automated tests (backend + frontend) | | | |
| Manual / QA testing | | | |
| Code review & PR iteration | | | |
| Contingency (__%) | | | |
| **Total (likely)** | | | |
| **Range (low – high)** | | | |

- **Range**: low = sum of optimistic anchors with minimum contingency; high = pessimistic anchors with full contingency. The likely number must sit inside the range. Compute a range for **each** column.
- **Blended speedup**: report `traditional total ÷ AI-assisted total` as a single ×-figure, and sanity-check it against the reality check above.
- **Confidence** (high/med/low) is tied to how many open assumptions remain — many unresolved estimate-moving assumptions ⇒ low. The AI-assisted figure inherits the traditional figure's confidence and is never *more* confident (the acceleration factors add their own uncertainty).
