# frozen_string_literal: true

class V1::UserSessions::FetchService < V1::UserSessions::BaseService
  def call
    @user_intervention = UserIntervention.find_by!(
      user_id: user_id,
      intervention_id: intervention_id,
      health_clinic_id: health_clinic_id
    )

    if user_intervention.contain_multiple_fill_session
      unfinished_session
    else
      find_user_session(:find_by!)
    end
  end
end
