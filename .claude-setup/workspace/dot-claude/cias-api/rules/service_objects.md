# Service Objects Convention

## Location
- Primary: `app/services/v1/` (API-versioned services)
- General: `app/services/` (shared services like `Communication::Sms`, `Hl7::*`, `Api::*`)

## Structure
Most services use the `.call()` class method pattern (preferred convention). Some older services (e.g., `FlowService`, `SessionService`, `UserInterventionService`) are instantiated directly — follow `.call()` for new code.

```ruby
class V1::MyFeature::DoSomething
  def self.call(param1, param2)
    new(param1, param2).call
  end

  def initialize(param1, param2)
    @param1 = param1
    @param2 = param2
  end

  def call
    # business logic
  end
end
```

There is **no single universal base class** for services. Some domain groups have their own base classes (e.g., `V1::UserSessions::BaseService`, `V1::ChartStatistics::Base`, `Api::CatMh::Base`). Cross-cutting concerns use `prepend`.

## Transactional Services
Use `prepend Database::Transactional` to wrap `call` in an ActiveRecord transaction:

```ruby
class V1::Organizations::Create
  prepend Database::Transactional

  def self.call(...)
    new(...).call
  end

  def call
    # automatically wrapped in transaction
  end
end
```

The module lives at `app/services/database/transactional.rb`.

## Organization
Services are grouped by domain under `v1/`:
- `v1/question/` — Create, Update, Destroy, ShareService
- `v1/organizations/` — Create, Update, ChangeOrganizationAdmins
- `v1/teams/`, `v1/health_systems/`, `v1/health_clinics/`
- `v1/generated_reports/` — GenerateUserSessionReports, ShareToThirdParty
- `v1/sms/`, `v1/sms_plans/` — SMS logic
- `v1/google/` — TranslationService
- `v1/henry_ford/` — VerifyService
- `v1/audio/` — Regenerate

External API services live under `app/services/api/`:
- `api/hfhs/`, `api/epic_on_fhir/`, `api/cat_mh/`, `api/documo/`

## What to Follow
- Always use `.call()` as the public interface — never instantiate directly
- Group related operations in a namespace (e.g., `V1::Question::Create`, `V1::Question::Update`)
- Use `prepend Database::Transactional` when the operation writes to multiple tables
- Keep services focused — one service, one responsibility
- Prefer IDs and simple params; some services (e.g., `V1::AnswerService`) accept param hashes when needed, but avoid passing raw controller `params` directly
