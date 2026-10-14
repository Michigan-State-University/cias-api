# Domain Model — CIAS Platform

CIAS is a healthcare intervention platform for delivering behavioral interventions via web, SMS, and computerized adaptive testing (CAT-MH).

## Core Entity Hierarchy

```
Organization
  └── HealthSystem (soft-delete via paranoia)
        └── HealthClinic (soft-delete via paranoia)

User (multi-role, encrypted PII)
  └── UserIntervention (status: ready_to_start → in_progress → completed | schedule_pending)
        └── UserSession (STI: Classic, Sms, CatMh)
              └── Answer (STI: 25 types, encrypted body)

Intervention (AASM: draft → published → paused/closed/archived)
  └── Session (STI: Classic, Sms, CatMh)
        ├── QuestionGroup (STI: Initial, Plain, Finish, Tlfb)
        │     └── Question (STI: 26 types)
        ├── SmsPlan (STI: Normal, Alert)
        │     └── SmsPlan::Variant (formula-based conditional content)
        └── ReportTemplate
```

## Intervention State Machine (AASM)
- `draft` → `published` or `archived`
- `published` → `closed` or `paused`
- `paused` → `published`
- `draft` or `closed` → `archived`

## Session Types (STI)
- `Session::Classic` — web-based questionnaire sessions
- `Session::Sms` — SMS-based sessions with scheduled question delivery
- `Session::CatMh` — computerized adaptive testing (CAT-MH vendor integration)

## Question Types (STI)
- **Response:** Single, Multiple, Slider, Grid, BarGraph, FreeResponse, Number, Currency, Date
- **Identity:** Name, Phone, ParticipantReport
- **Information:** Information, Feedback, ExternalLink, FollowUpContact, Finish
- **SMS:** Sms, SmsInformation
- **Assessment:** Tlfb, TlfbQuestion, TlfbEvents, TlfbConfig
- **Vendor-specific:** HenryFord, HenryFordInitial, ThirdParty

Note: `Question::Narrator` exists but is a helper/service class, NOT an STI subclass.

Questions must match their session type — SMS questions only in SMS sessions.

## Answer Types (STI)
25 types mirroring question types plus Answer::CatMh. Examples: Answer::Single, Answer::Multiple, Answer::Name, etc.
- `body` is **Lockbox-encrypted** JSONB (`body_ciphertext` column, use `decrypted_body` to read)
- `draft: true` means unsaved/in-progress
- `skipped: true` means participant skipped the question
- `alternative_branch: true` means a conditional branch was taken

## User Roles (array field, multiple roles per user)
```
guest, preview_session, participant, third_party,
health_clinic_admin, health_system_admin, organization_admin,
researcher, e_intervention_admin, team_admin, admin,
navigator, predefined_participant
```

## Key JSONB Columns
| Model | Column | Purpose |
|-------|--------|---------|
| Session | `settings` | UI/behavior configuration |
| Session | `formulas` | Conditional skip/branching logic |
| Session | `original_text` | Translation tracking |
| Question | `narrator` | Audio/animation narrator blocks |
| Question | `body` | Answer options (structure varies by type) |
| Question | `formulas` | Question-level branching logic |
| SmsPlan | `sms_send_time_details` | Time window configuration |
| All text models | `original_text` | Stores original values for translation tracking |

## Conditional Branching
- `formulas` JSONB on sessions, question_groups, and questions
- Evaluated by Dentaku calculator engine using participant answer variables
- `Answer#next_session_id` allows jumping to a different session
- SmsPlan variants use `formula` + `formula_match` for conditional SMS content

## Important Patterns
- **Primary keys are UUIDs** (`uuid_generate_v4()`) on all core domain tables; some lookup/junction tables (e.g., `cat_mh_*`, `alert_phones`) use integer IDs
- **Soft deletes** only on HealthSystem and HealthClinic (paranoia gem, `deleted_at`)
- **Audit trail**: Paper Trail (version history) + Audited gem (all ApplicationRecord subclasses)
- **Encryption**: User PII (email, first_name, last_name, uid) and Answer body via Lockbox
- **Blind indexes**: Searchable encrypted fields (email_bidx, uid_bidx) without decryption
- **Counter caches**: sessions_count on interventions, questions_count on question_groups, sms_plans_count on sessions, report_templates_count on sessions
