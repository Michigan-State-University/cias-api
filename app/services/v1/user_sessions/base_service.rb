# frozen_string_literal: true

class V1::UserSessions::BaseService
  def self.call(session_id, user_id, health_clinic_id)
    new(session_id, user_id, health_clinic_id).call
  end

  def initialize(session_id, user_id, health_clinic_id)
    @session_id = session_id
    @user_id = user_id
    @health_clinic_id = health_clinic_id
    @session = Session.find(session_id)
    @type = session.user_session_type
    @intervention_id = session.intervention_id
  end

  attr_reader :health_clinic_id, :type, :intervention_id, :session_id, :user_id, :session
  attr_accessor :user_intervention

  def call
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  protected

  def new_user_session_for(create_method, counter = 1)
    user_session = UserSession.send(
      create_method,
      session_id: session_id,
      user_id: user_id,
      health_clinic_id: health_clinic_id,
      type: type,
      user_intervention_id: user_intervention.id,
      number_of_attempts: counter
    )
    user_session.started = true
    user_session
  end

  def find_user_session(find_method)
    UserSession.send(
      find_method,
      session_id: session_id,
      user_id: user_id,
      health_clinic_id: health_clinic_id,
      type: type,
      user_intervention_id: user_intervention.id
    )
  end

  def started_sessions
    @started_sessions ||= user_intervention.user_sessions.where(
      session_id: session_id, user_id: user_id, health_clinic_id: health_clinic_id, type: type, user_intervention_id: user_intervention.id
    )
  end

  def unfinished_session
    started_sessions.find_by!(finished_at: nil)
  end

  def number_of_attempts
    user_intervention.contain_multiple_fill_session ? started_sessions.count + 1 : nil
  end
end
