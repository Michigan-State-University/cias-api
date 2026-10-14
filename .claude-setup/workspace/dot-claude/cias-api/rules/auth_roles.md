# Authentication & Authorization

## Authentication Stack
- **Devise** with: confirmable, database_authenticatable, invitable, recoverable, registerable, rememberable, timeoutable, trackable, validatable, argon2
- **devise-argon2** — password hashing via Argon2
- **token_cost** — 4 (test), 10 (production) — configured in `devise_token_auth.rb`
- **devise_token_auth** — stateless token-based API auth
- **devise_invitable** — user invitation flow

## Token Auth Flow
- Token lifespan: 15 minutes
- Tokens rotate on each request (except test env)
- Required request headers: `Access-Token`, `Client`, `Expiry`, `Uid`, `Token-Type`, `authorization`
- Tokens stored in User `tokens` JSONB column
- Auth controllers: `app/controllers/v1/auth/` (sessions, registrations, passwords, confirmations)
- Login includes 2FA verification code check

## User Roles
Stored as string array in `roles` column. A user can have multiple roles.

```ruby
APP_ROLES = %w[
  guest preview_session participant third_party
  health_clinic_admin health_system_admin organization_admin
  researcher e_intervention_admin team_admin admin
  navigator predefined_participant
]
```

Role checks: `user.role?('researcher')` or dynamic `user.researcher?`

## CanCanCan Authorization
- Main class: `app/models/ability.rb` — injects role-specific ability modules
- Role abilities: `app/models/ability/{role_name}.rb`
- Each role class inherits `Ability::Base` and defines permissions
- Shared permission sets via `Ability::Generic::*` mixins (e.g., `GoogleAccess`, `SmsPlanAccess`, `ReportTemplateAccess`)

### Role Hierarchy (simplified)
- **participant** — fill interventions, read own reports
- **researcher** — full intervention CRUD, manage collaborators, export data
- **team_admin** — manage team members and their interventions
- **e_intervention_admin** — manage interventions across organizations
- **organization_admin** — manage organization, health systems, clinics
- **health_system_admin / health_clinic_admin** — scoped to their entity
- **admin** — full system access
- **navigator** — live chat with participants

### Controller Pattern
```ruby
authorize! :read, Intervention   # class-level check
authorize! :update, @intervention # instance-level check
```

## User Encryption (Lockbox)
- Encrypted fields: `email`, `first_name`, `last_name`, `uid`
- Columns: `*_ciphertext` (e.g., `email_ciphertext`)
- Blind indexes for search: `email_bidx`, `uid_bidx`
- Audited gem excludes all encrypted fields from audit log

## Account Deactivation
- `user.active` boolean (default: true)
- `V1Controller#block_deactivated_account` raises `CanCan::AccessDenied` if inactive
- Deactivated users cannot authenticate
