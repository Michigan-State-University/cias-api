# frozen_string_literal: true

class RegenerateChartsJob < ApplicationJob
  include ChartRegenerationLockManagement

  queue_as :default

  def perform(chart_ids, replace: true, user_id: nil)
    ids = Array(chart_ids)
    Rails.logger.warn "[#{self.class.name}] Regenerating #{ids.size} chart(s) " \
                      "[#{ids.join(', ')}], replace=#{replace}, user_id=#{user_id}"
    V1::Charts::Regenerate.call(chart_ids, replace: replace)

    notify_requester(ids, user_id)
  end

  def chart_ids_for_lock_cleanup
    Array(arguments.first)
  end

  private

  # user_id is nil for the batch caller and the rake task, so those paths send nothing.
  def notify_requester(chart_ids, user_id)
    return if user_id.blank?

    user = User.find_by(id: user_id)
    return if user.nil? || !user.email_notification

    Chart.unscoped.where(id: chart_ids).find_each do |chart|
      ChartRegenerationMailer.regeneration_complete(user, chart).deliver_now
    end
  end
end
