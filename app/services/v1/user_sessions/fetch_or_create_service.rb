# frozen_string_literal: true

class V1::UserSessions::FetchOrCreateService
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

  def started_sessions
    @started_sessions ||= user_intervention.user_sessions.where(
      session_id: session_id, user_id: user_id, health_clinic_id: health_clinic_id, type: type, user_intervention_id: user_intervention.id
    )
  end

  def unfinished_session
    started_sessions.find_by(finished_at: nil)
  end

  def number_of_attempts
    started_sessions.count + 1
  end

  def new_user_session_for(create_method, counter = 1)
    UserSession.send(
      create_method,
      session_id: session_id,
      user_id: user_id,
      health_clinic_id: health_clinic_id,
      type: type,
      user_intervention_id: user_intervention.id,
      number_of_attempts: counter
    )
  end
end
