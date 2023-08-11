# frozen_string_literal: true

class DeleteUserReports < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    return if intervention.blank?

    intervention.user_sessions.each do |user_session|
      user_session.generated_reports.destroy_all
    end

    # TODO: check if they actually delete what they need to delete

    intervention.update!(reports_deleted: true)
  end
end
