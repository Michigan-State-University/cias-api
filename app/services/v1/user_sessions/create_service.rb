# frozen_string_literal: true

class V1::UserSessions::CreateService < V1::UserSessions::BaseService
  def call
    @user_intervention = UserIntervention.find_or_create_by(
      user_id: user_id,
      intervention_id: intervention_id,
      health_clinic_id: health_clinic_id
    )

    @user_intervention.in_progress!

    User.find(user_id).update!(language_code: @user_intervention.intervention.language_code)
    new_user_session_for(:new, number_of_attempts)
  end
end
