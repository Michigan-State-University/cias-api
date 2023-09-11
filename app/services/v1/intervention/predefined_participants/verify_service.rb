# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::VerifyService
  def initialize(slug)
    @slug = slug
  end

  def self.call(slug)
    new(slug).call
  end

  def call
    {
      intervention_id: predefined_user_parameter.intervention_id,
      session_id: session&.id,
      health_clinic_id: predefined_user_parameter.health_clinic_id,
      multiple_fill_session_available: multiple_fill_session_available,
      user_intervention_id: user_intervention.id
    }
  end

  attr_reader :slug

  private

  def predefined_user_parameter
    @predefined_user_parameter ||= PredefinedUserParameter.find_by!(slug: slug)
  end

  def user_intervention
    @user_intervention ||= UserIntervention.find_by(user_id: predefined_user_parameter.user_id, intervention_id: predefined_user_parameter.intervention_id)
  end

  def intervention
    @intervention ||= user_intervention.intervention
  end

  def session
    return nil if intervention.sessions.blank?

    user_sessions = UserSession.where(user_intervention: user_intervention).order(:last_answer_at)
    user_sessions_in_progress = user_sessions.where(finished_at: nil).where('scheduled_at = ? OR scheduled_at >', nil, DateTime.now)

    return user_sessions_in_progress.last.session if user_sessions_in_progress.any?
    return nil if intervention.type.eql?('Intervention::FlexibleOrder')

    return intervention.sessions.order(:position).first if user_sessions.blank?

    next_session = user_sessions.last.next_session
    next_user_session = UserSession.find_by(session_id: next_session.id)

    return next_session if next_user_session.blank?
    return nil if next_user_session.scheduled_at&.future?

    next_session
  end

  def multiple_fill_session_available
    UserSession.joins(:session).where(user_intervention: user_intervention, session: { multiple_fill: true }).where.not(finished_at: nil).any?
  end
end
