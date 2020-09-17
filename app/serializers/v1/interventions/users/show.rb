# frozen_string_literal: true

class V1::Interventions::Users::Show < BaseSerializer
  def cache_key
    "interventions/user/#{@user_intervention.id}-#{@user_intervention.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @user_intervention.id,
      user_id: @user_intervention.user_id,
      email: @user_intervention.user.email,
      intervention_id: @user_intervention.intervention_id,
      submitted_at: @user_intervention.submitted_at,
      schedule_at: @user_intervention.schedule_at
    }
  end
end
