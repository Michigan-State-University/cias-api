# API Controllers & Serialization

## Controller Structure
- All controllers live under `app/controllers/v1/` and inherit from `V1Controller`
- `V1Controller` inherits `ApplicationController` and includes:
  - `DeviseTokenAuth::Concerns::SetUserByToken` — token auth
  - `ExceptionHandler` — centralized error handling
  - `Pagination` — via Pagy gem
  - `Resource` — serialization helpers
- Default `before_action`: `authenticate_user!`, `set_paper_trail_whodunnit`, `block_deactivated_account`

## Authorization Pattern
Most controller actions authorize with CanCanCan. Some read actions (e.g., `index`, `show` on Interventions, Users, Tags) rely on scoping instead of explicit `authorize!` calls.

```ruby
# Explicit authorization (most actions)
def show
  authorize! :read, Question
  authorize! :read, question_load
  render json: serialized_response(question_load)
end

# Scoped access (some read actions)
def index
  collection = sorted_interventions_scope.detailed_search(params, current_v1_user)
  render json: serialized_response(collection)
end
```

## Response Serialization
- Uses `jsonapi-serializer` gem (JSONAPI::Serializer)
- Serializers live in `app/serializers/v1/` and inherit from `V1Serializer`
- Rendering via `Resource` concern helper:

```ruby
# Automatically resolves serializer from controller name
render json: serialized_response(resource)

# Or specify model name explicitly
render json: serialized_response(collection, 'Question')
```

The helper resolves to `V1::{ModelName}Serializer`.

## Serializer Convention

```ruby
class V1::QuestionSerializer < V1Serializer
  attributes :type, :position, :title, :body, :settings

  attribute :image_url do |object|
    polymorphic_url(object.image) if object.image.attached?
  end

  attribute :special_field, if: proc { |record| record.is_a?(Question::Phone) } do |object|
    # conditional attributes
  end
end
```

## Error Handling
- `ComplexException` — custom exception with `message`, `additional_information`, `status_code`
- `ExceptionHandler` concern rescues common exceptions and returns JSON errors
- Critical exceptions are sent to Sentry with context

## Token Authentication (DeviseTokenAuth)
- Token lifespan: **15 minutes**
- Required headers: `Access-Token`, `Client`, `Expiry`, `Uid`, `Token-Type`
- Tokens rotate on each request (except in test env)
- Password hashing: Argon2

## ActionCable Channels
Three WebSocket channels in `app/channels/`:
- **NotificationChannel** — streams per-user notifications, navigator availability
- **InterventionChannel** — concurrent editing locks per intervention
- **ConversationChannel** — real-time live chat between participants and navigators

Connection identified by user via `uid` + `access_token` + `client` params.
§