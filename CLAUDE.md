# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

CIAS 3.0 (Computerized Intervention Authoring System) backend — a JSON-only Rails 8.1 API (`ActionController::API`), Ruby 3.3.8, PostgreSQL, Redis, Sidekiq. The frontend lives in a separate repo (`cias-web`). Main branch for PRs is `dev`.

## Commands

```bash
bundle install
cp .env.template .env                  # first-time setup
rails db:migrate:reset                 # set up a fresh DB
rails db:seed                          # role-based seed users (never in production)
./db_reset.sh                          # reset local DB
rails s                                # API on localhost:3000
bundle exec sidekiq -C config/sidekiq.yml   # background worker

bundle exec rubocop                    # lint (CI runs this; must pass)
bundle exec rspec                      # full suite
bundle exec rspec spec/requests/v1/interventions/create_spec.rb      # single file
bundle exec rspec spec/requests/v1/interventions/create_spec.rb:42   # single example
bundle exec rspec spec/benchmarks/*/*.rb                             # benchmarks
bundle exec rake parallel:setup        # create cias_test, cias_test2, … (one DB per CPU core)
bundle exec parallel_rspec spec/       # run the suite in parallel
bundle-audit check --update            # dependency audit (CI runs this)
```

Tests need running PostgreSQL and Redis. CI loads the DB with `rails db:create db:schema:load` (schema lives in `db/schema.rb`). On macOS, audio generation may crash on fork — set `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`.

Dev helpers: `/rails/browse_emails` (letter_opener), `/rails/info/routes`, `/rails/workers` (Sidekiq UI, requires `SIDEKIQ_WEB_INTERFACE=1`).

## Architecture

### Request pipeline
- All endpoints are under `namespace :v1` in `config/routes.rb`; controllers inherit from `V1Controller` (`app/controllers/v1_controller.rb`).
- Auth: `devise_token_auth` — clients send token headers (`user.create_new_auth_token` in specs). `authenticate_user!` and `block_deactivated_account` run for every V1 action.
- Authorization: CanCanCan. `Ability` (`app/models/ability.rb`) composes rules dynamically from the user's `roles` array — each role maps to `Ability::<Role>` in `app/models/ability/` (admin, researcher, participant, guest, preview_session, navigator, e_intervention_admin, health_system_admin, …). Adding a role means adding a class there.
- Errors: `ExceptionHandler` concern maps exceptions to HTTP statuses (RecordNotFound → 404, AccessDenied → 403, RecordInvalid → 422, …) and reports to Sentry. Raise `ComplexException.new(message, details, status)` for custom error payloads rather than rendering errors manually.
- `Resource` concern: `serialized_response` / `serialized_hash` resolve `V1::<Model>Serializer` from the controller name. `Resource::Position`, `Resource::Reorder`, `Resource::Clone` are shared behaviors for orderable/clonable resources.
- Audit trail: `paper_trail` (whodunnit set in `V1Controller`) and `audited`.

### Domain model
Intervention → Session → QuestionGroup → Question, with participant runtime state in UserIntervention → UserSession → Answer.
- Heavy STI: `Question::*` (Single, Multiple, Grid, Tlfb, Phone, Finish, …), `Session::Classic/CatMh/Sms`, `UserSession::Classic/CatMh/Sms`, `Intervention::FixedOrder/FlexibleOrder`, `Answer::*`. New question types need a subclass plus matching answer/serializer handling.
- JSON columns (`body`, `formulas`, `narrator`, …) get defaults via `DefaultValues`; formulas/branching are evaluated with Dentaku.
- Participant flow (next question, branching, reflections, CAT-MH) is driven by `V1::FlowService` and its sub-services in `app/services/v1/flow_service/`.
- PHI is encrypted with `lockbox` + `blind_index` (User, Answer, Phone, Message, …) — query encrypted fields through their blind indexes, not raw columns.
- Soft delete via `paranoia`.

### Services, jobs, serializers
- Business logic lives in `app/services/` (mostly `V1::` namespace, many with a `.call` interface); external integrations in `app/services/api/` (CAT-MH, Epic on FHIR, Henry Ford/HL7, Google TTS/Translate, Twilio).
- Two serializer styles: `V1Serializer` subclasses (jsonapi-serializer) used by `Resource` helpers, and `BaseSerializer` / `active_model_serializers` for others — follow whichever the surrounding endpoint uses.
- Long-running work (cloning, CSV export, reports/PDF via wicked_pdf, translations, SMS plans, audio) runs in Sidekiq jobs; queues are defined in `config/sidekiq.yml`.
- Real-time: ActionCable channels in `app/channels/` (live chat, intervention, notifications).
- Config via the `config` gem (`config/settings.yml`, `config/settings/*.yml`) and ENV (`.env.template` lists variables).

## Testing conventions
- Request specs live in `spec/requests/v1/<resource>/<action>_spec.rb` (one file per endpoint action) and use shared examples from `spec/support/shared_examples` (e.g. `it_behaves_like 'unauthorized user'`).
- FactoryBot with traits such as `create(:user, :confirmed, :researcher)`.
- Bullet is enabled in tests and wraps each example — N+1 queries surface as failures, so add `includes` where needed.
- WebMock is in the test group — stub calls to third-party APIs (`stub_request`) rather than hitting them.

## Code style
- RuboCop with rails/rspec/performance/thread_safety plugins; max line length 160. Files start with `# frozen_string_literal: true`.
- Overcommit hooks (if installed) reject `TODO`/`FIXME`/`NOTE`/`HACK` etc. tokens, trailing whitespace and merge-conflict markers in committed files.
