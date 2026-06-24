# frozen_string_literal: true

class E2e::CleanupJob < ApplicationJob
  queue_as :default

  def perform
    return unless %w[development test].include?(ENV.fetch('APP_ENVIRONMENT', nil))

    E2e::CleanupService.call
  end
end
