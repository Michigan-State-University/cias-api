# frozen_string_literal: true

class V1::UserInterventionService
  attr_reader :user_intervention, :current_user_session_id

  def initialize(user_intervention_id, current_user_session_id)
    @user_intervention = UserIntervention.find(user_intervention_id)
    @current_user_session_id = current_user_session_id
  end

  def var_values(always_include_session_var = false)
    user_sessions.each_with_object({}) do |user_session, var_values|
      include_session_var = always_include_session_var ? true : current_user_session_id != user_session.id
      var_values.merge!(user_session.all_var_values(include_session_var: include_session_var))
    end
  end

  private

  def user_sessions
    user_intervention.latest_user_sessions
  end
end
