# Database Patterns & Conventions

## PostgreSQL
- Extensions: `uuid-ossp`, `pgcrypto`, `btree_gin`
- **Core domain tables use UUID primary keys** generated via `uuid_generate_v4()`
- Some lookup/junction tables (e.g., `cat_mh_*`, `alert_phones`, `active_storage_*`) use integer IDs
- Foreign keys referencing UUID tables are UUIDs

## STI (Single Table Inheritance)
Widely used — always set `type` column when creating records:
- Session: Classic, Sms, CatMh
- UserSession: Classic, Sms, CatMh
- Question: 26 types
- Answer: 25 types (mirrors Question types + CatMh)
- SmsPlan: Normal, Alert
- QuestionGroup: Initial, Plain, Finish, Tlfb

## JSONB Columns
Many models store structured data in JSONB. Key ones:
- `settings` — UI/behavior configuration (sessions, questions)
- `formulas` — conditional branching logic (sessions, question_groups, questions)
- `narrator` — audio/animation blocks (questions)
- `body` — answer options/content structure (questions — schema varies by STI type)
- `original_text` — stores original values before translation
- `tokens` — DeviseTokenAuth tokens (users)
- `sms_schedule` — SMS delivery timing (question_groups)
- `sms_send_time_details` — time windows (sms_plans)

## Encryption (Lockbox + blind_index)
- **User:** email, first_name, last_name, uid → `*_ciphertext` columns + `*_bidx` blind indexes
- **Answer:** body → `body_ciphertext` (type: :json, migrating: true)
- **HfhsPatientDetail:** patient_id, first_name, last_name, dob, sex, zip_code, phone_number, etc.
- **Phone:** number field encrypted
- **Message:** phone field encrypted
- Use `decrypted_body` to read encrypted Answer content
- Query encrypted fields via blind index columns (e.g., `User.where(email_bidx: ...)`)

## Soft Deletes (Paranoia)
Only on: `HealthSystem`, `HealthClinic`
- `deleted_at` datetime column
- `acts_as_paranoid` provides `.with_deleted`, `.only_deleted` scopes
- Default scopes exclude deleted records

## Audit Trail
- **Paper Trail** (`has_paper_trail`) — version history on 40+ models, creates `versions` table records
- **Audited** — enabled globally via `ApplicationRecord`, creates `audits` table records
- Encrypted fields excluded from both audit systems

## Counter Caches
- `sessions_count` on interventions
- `questions_count` on question_groups
- `sms_plans_count` on sessions
- `report_templates_count` on sessions

## Important Scopes
- `Intervention.published`, `.draft`, `.paused`, `.closed`
- `Answer.confirmed` (draft: false), `.final` (alternative_branch: false), `.hfhs`
- `User.researchers`, `.participants`, `.confirmed`, `.limit_to_roles(roles)`
- HealthSystem/HealthClinic: `.with_deleted`, `.only_deleted`

## Conventions
- Use UUIDs for new domain tables; integer IDs acceptable for small lookup/reference tables
- Always add `null: false` constraints on required columns
- Use `position` integer columns for ordering (default: 0 or 1)
- Use `type` column for STI — never store it as anything else
- JSONB columns should have a `default: {}` or `default: []`
- Encrypted fields: add both `*_ciphertext` and `*_bidx` columns
