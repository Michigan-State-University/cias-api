# frozen_string_literal: true

class E2e::CleanupService
  class << self
    delegate :call, to: :new
  end

  def call
    Rails.logger.info 'Starting E2E interventions cleanup...'

    roles = %w[admin researcher participant]
    worker_count = ENV.fetch('E2E_WORKER_COUNT', 5).to_i

    target_emails = []
    roles.each do |role|
      worker_count.times do |i|
        target_emails << "e2e_#{role}_#{i}@example.com"
      end
    end

    Rails.logger.info "Targeting #{target_emails.count} specific E2E email addresses."

    e2e_user_ids = []
    User.find_each do |user|
      e2e_user_ids << user.id if target_emails.include?(user.email)
    end

    if e2e_user_ids.empty?
      Rails.logger.info 'No E2E users found.'
      return
    end

    Rails.logger.info "Found #{e2e_user_ids.count} E2E users."

    interventions = Intervention.where(user_id: e2e_user_ids)
    count = interventions.count

    if count.zero?
      Rails.logger.info 'No interventions found for E2E users.'
    else
      interventions.each do |intervention|
        intervention.sessions.destroy_all
        intervention.user_interventions.destroy_all
        intervention.conversations.destroy_all
        intervention.destroy
      end

      Rails.logger.info "Deleted #{count} interventions created by E2E users."
    end
  end
end
