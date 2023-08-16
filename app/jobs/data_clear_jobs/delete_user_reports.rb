# frozen_string_literal: true

class DataClearJobs::DeleteUserReports < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    intervention.user_sessions.each do |user_session|
      user_session.generated_reports.destroy_all
    end

    intervention.generated_reports_removed!
  end
end
