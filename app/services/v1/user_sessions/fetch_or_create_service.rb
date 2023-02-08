# frozen_string_literal: true

class V1::UserSessions::FetchOrCreateService < V1::UserSessions::BaseService
  def call
    @user_intervention = UserIntervention.find_or_create_by(
      user_id: user_id,
      intervention_id: intervention_id,
      health_clinic_id: health_clinic_id
    )
    if user_intervention.contain_multiple_fill_session
      unfinished_session || new_user_session_for(:new, number_of_attempts)
    else
      new_user_session_for(:find_or_initialize_by)
    end
  end

  private

  def unfinished_session
    started_sessions.find_by(finished_at: nil)
  end
end
