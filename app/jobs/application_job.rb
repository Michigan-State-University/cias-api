# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on StandardError, wait: 1.hour, attempts: Settings.sidekiq.retries

  JobTimeoutError = Class.new(StandardError)
  around_perform do |_job, block|
    # Timeout jobs after 10 minutes
    Timeout.timeout(10.minutes, JobTimeoutError) do
      block.call
    end
  end

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def module_name
    self.class.to_s.deconstantize.chomp('Job')
  end
end
