# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::FulfillRaSessionService
  Result = Struct.new(:user_session, :already_completed, keyword_init: true)

  def self.call(intervention:, participant:, fulfilled_by:, health_clinic_id:)
    new(intervention: intervention, participant: participant, fulfilled_by: fulfilled_by, health_clinic_id: health_clinic_id).call
  end

  def initialize(intervention:, participant:, fulfilled_by:, health_clinic_id:)
    @intervention = intervention
    @participant = participant
    @fulfilled_by = fulfilled_by
    @health_clinic_id = health_clinic_id
  end

  def call
    return Result.new(user_session: user_session, already_completed: true) if user_session.finished_at.present?

    user_session.update!(fulfilled_by_id: fulfilled_by.id, started: true)
    user_intervention.in_progress! if user_intervention.ready_to_start?

    Result.new(user_session: user_session, already_completed: false)
  end

  private

  attr_reader :intervention, :participant, :fulfilled_by, :health_clinic_id

  def ra_session
    @ra_session ||= intervention.ra_session || raise(ActiveRecord::RecordNotFound, 'RA session not found')
  end

  def user_intervention
    @user_intervention ||= UserIntervention.find_or_create_by(
      user_id: participant.id,
      intervention_id: intervention.id,
      health_clinic_id: health_clinic_id
    )
  end

  def user_session
    @user_session ||= UserSession::ResearchAssistant.find_or_create_by(
      session_id: ra_session.id,
      user_id: participant.id,
      type: 'UserSession::ResearchAssistant',
      user_intervention_id: user_intervention.id,
      health_clinic_id: health_clinic_id
    )
  end
end
