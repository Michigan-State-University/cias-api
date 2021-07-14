# frozen_string_literal: true

class V1::UserInterventionService
  attr_reader :user_id, :intervention_id, :current_user_session_id

  def initialize(user_id, intervention_id, current_user_session_id)
    @user_id = user_id
    @intervention_id = intervention_id
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
    UserSession.where(user_id: user_id).joins(:session).where(sessions: { intervention: intervention_id })
  end
end
