# frozen_string_literal: true

class V1::ChartStatistics::CreateForUserSessions
  # Must sit between ApplicationJob's 30-minute Timeout and retry_on's 1-hour wait: lower steals a
  # live run's lock, higher leaves the queued retry finding it still held.
  LOCK_TTL = 45.minutes

  def self.call(chart_id, replace: false)
    new(chart_id, replace: replace).call
  end

  def initialize(chart_id, replace: false)
    @chart_id = chart_id
    @replace = replace
  end

  def call
    unless chart_exists?
      Rails.logger.warn "[#{self.class.name}] Chart #{chart_id} no longer exists, nothing to do"
      return
    end

    unless lock_acquired?
      Rails.logger.warn "[#{self.class.name}] Chart #{chart_id} is already regenerating, skipping"
      return
    end

    Rails.logger.warn "[#{self.class.name}] Started for chart #{chart_id}"

    begin
      ActiveRecord::Base.transaction do
        if replace
          destroyed = ChartStatistic.where(chart_id: chart_id).destroy_all.size
          Rails.logger.warn "[#{self.class.name}] Destroyed #{destroyed} row(s) for chart #{chart_id} before replay"
        end
        create_statistics
      end
    rescue StandardError => e
      Rails.logger.error "[#{self.class.name}] Failed for chart #{chart_id}, will retry. Lock remains held. Error: #{e.message}"
      raise
    end

    log_duplicate_cells
    release_lock
    Rails.logger.warn "[#{self.class.name}] Finished for chart #{chart_id}"
  end

  private

  attr_reader :chart_id, :replace

  def create_statistics
    user_sessions.each do |user_session|
      next if user_session.session.intervention.draft?

      V1::ChartStatistics::Create.call(chart, user_session, organization)
    end
  end

  # rubocop:disable Rails/SkipsModelValidations
  def lock_acquired?
    @lock_token = Time.current.round(6)
    Chart.unscoped
         .where(id: chart_id)
         .where('regenerating_since IS NULL OR regenerating_since < ?', LOCK_TTL.ago)
         .update_all(regenerating_since: @lock_token, updated_at: Time.current)
         .positive?
  end

  def release_lock
    Chart.unscoped.where(id: chart_id, regenerating_since: @lock_token)
         .update_all(regenerating_since: nil, updated_at: Time.current)
  end

  def chart_exists?
    Chart.unscoped.exists?(id: chart_id)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def log_duplicate_cells
    duplicates = ChartStatistic.where(chart_id: chart_id)
                               .group(:organization_id, :health_system_id, :health_clinic_id, :chart_id, :user_id)
                               .having('COUNT(*) > 1').count

    return if duplicates.empty?

    surplus = duplicates.values.sum - duplicates.size
    Rails.logger.warn "[#{self.class.name}] Chart #{chart_id} left #{duplicates.size} duplicate cell(s) " \
                      "(#{surplus} surplus row(s)) after regeneration"
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Duplicate detection failed for chart #{chart_id}: #{e.message}"
  end

  def user_sessions
    UserSession.joins(session: [intervention: :organization]).preload(session: :intervention).where(
      sessions: {
        interventions: { organization: organization },
        variable: chart_session_variables
      }
    ).where.not(finished_at: nil)
  end

  def organization
    @organization ||= chart.dashboard_section.reporting_dashboard.organization
  end

  def chart
    @chart ||= Chart.find(chart_id)
  end

  def chart_session_variables
    chart.chart_variables.map { |variable| variable.split('.').first }
  end
end
