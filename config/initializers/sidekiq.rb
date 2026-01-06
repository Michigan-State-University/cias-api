# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.on(:startup) do
    schedule_file = Rails.root.join('config/schedule.yml')

    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file) if defined?(Sidekiq::Cron::Job) && File.exist?(schedule_file)
  end
end
