# frozen_string_literal: true

module ChartRegenerationLockManagement
  extend ActiveSupport::Concern

  def chart_ids_for_lock_cleanup
    raise NotImplementedError, "#{self.class.name} must implement #chart_ids_for_lock_cleanup"
  end

  included do
    sidekiq_retries_exhausted do |msg, _ex|
      job_name = msg['wrapped'] || msg['class']

      begin
        job = ActiveJob::Base.deserialize(msg['args'].first)
        job.send(:deserialize_arguments_if_needed)
        chart_ids = Array(job.chart_ids_for_lock_cleanup).compact

        if chart_ids.any?
          Chart.unscoped.where(id: chart_ids).update_all(regenerating_since: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
          Rails.logger.warn "[#{job_name}] Released regeneration lock for #{chart_ids.size} chart(s) after retries exhausted"
        else
          Rails.logger.error "[#{job_name}] Could not determine chart ids to release lock. Args: #{msg['args']}"
        end
      rescue StandardError => e
        Rails.logger.error "[#{job_name}] Failed to release regeneration lock on retry exhaustion: #{e.message}"
        Sentry.capture_exception(e)
      end
    end
  end
end
