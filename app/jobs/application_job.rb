# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on Exception, wait: 1.hour, attempts: Settings.sidekiq.retries

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def module_name
    self.class.to_s.deconstantize.chomp('Job')
  end
end
