# Sidekiq / Background Jobs

## Stack
- Sidekiq 7.x with ActiveJob adapter (`queue_adapter = :sidekiq`)
- All jobs inherit from `ApplicationJob` (which itself inherits `ActiveJob::Base`)
- Global retry: `retry_on StandardError, wait: 1.hour, attempts: Settings.sidekiq.retries`
- Global timeout: 30 minutes via `around_perform` in `ApplicationJob`

## Job Structure

- Always inherit from `ApplicationJob`, never directly from `ActiveJob::Base`
- Always specify a queue with `queue_as`
- Accept only serializable arguments in `perform`: IDs and primitives, never AR objects
- Use `find_by` (not `find`) and guard with early returns for missing records

```ruby
class MyJob < ApplicationJob
  queue_as :default

  def perform(record_id)
    record = MyModel.find_by(id: record_id)
    return if record.blank?

    MyService.call(record)
  end
end
```

## Queues
Use the appropriate queue from `config/sidekiq.yml`:
- `default` — general purpose
- `reports` — report generation
- `sms_plans` / `question_sms` — SMS-related jobs
- `mailers` — email delivery
- `clone` — cloning/duplication jobs
- `translations` — translation jobs
- `session_finish` — post-session processing
- `hfhs` — Henry Ford Health System integration
- `log` — low-priority logging
- `active_storage_purge` / `active_storage_analysis` — file jobs

Do not invent new queues without adding them to `config/sidekiq.yml`.

## Retry Behaviour

- Default retry is inherited from `ApplicationJob` — do not re-declare it unless you need different behaviour
- Disable retries explicitly only when retrying would cause harm (e.g. imports):
  ```ruby
  sidekiq_options retry: false
  ```
- Use `sidekiq_retries_exhausted` (via a concern) for cleanup when all retries are exhausted

## Idempotency

- Every job must be safe to run more than once with the same arguments
- Use database locks or flag columns (e.g. `formula_update_in_progress`) to guard re-entrant work
- Wrap non-idempotent operations in transactions where appropriate

## Abstract / Base Jobs

When creating a family of jobs, use a base class with `NotImplementedError`:

```ruby
class CloneJob < ApplicationJob
  queue_as :clone

  def perform(*_args)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
```

## Shared Logic

Use concerns under `app/jobs/concerns/` with `included do` for shared callbacks:

```ruby
module MyLockManagement
  extend ActiveSupport::Concern

  included do
    sidekiq_retries_exhausted do |msg, _ex|
      # cleanup
    end
  end
end
```

## Enqueuing Jobs

- Use `perform_later` for async execution
- Use `perform_now` only in tests or when synchronous execution is explicitly required
- Chain jobs from within other jobs when needed:
  ```ruby
  AnotherJob.perform_later(record.id)
  ```

## Testing

- Use `have_enqueued_mail` / `have_enqueued_job` matchers in specs
- Test `perform_now` directly in unit tests; avoid `perform_later` in specs
- Use `ActiveJob::TestHelper` (`assert_enqueued_with`) or RSpec's `ActiveJob` matchers

## What to Avoid

- Do not pass ActiveRecord objects as job arguments — pass IDs
- Do not use `Sidekiq::Worker` directly; always go through ActiveJob (`ApplicationJob`)
- Do not sleep inside jobs — use scheduling or re-enqueue with delay
- Do not rescue `Exception` — let jobs fail and rely on Sidekiq retry mechanism
- Do not hardcode retry counts inline unless `ApplicationJob` defaults are truly wrong for that job
