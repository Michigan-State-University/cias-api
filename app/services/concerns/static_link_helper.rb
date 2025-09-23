# frozen_string_literal: true

module StaticLinkHelper
  def available_now_session(intervention, user_intervention)
    return nil if intervention.sessions.blank?
    return nil if user_intervention&.completed?

    user_sessions = UserSession.where(user_intervention: user_intervention).order(:last_answer_at)
    user_sessions_in_progress = user_sessions.where(finished_at: nil).where('scheduled_at IS NULL OR scheduled_at < ?', DateTime.now)

    return user_sessions_in_progress.last.session if user_sessions_in_progress.any?
    return nil if intervention.type.eql?('Intervention::FlexibleOrder')

    return intervention.sessions.order(:position).first if user_sessions.blank?

    next_session = user_sessions.where.not(finished_at: nil).last.session.next_session
    next_user_session = UserSession.find_by(session_id: next_session.id)

    return next_session if next_user_session.blank?
    return nil if next_user_session.scheduled_at&.future?

    next_session
  end

  def multiple_fill_session_available?(user_intervention)
    finished_multiple_fill_user_sessions = UserSession.joins(:session).where(user_intervention: user_intervention,
                                                                             session: { multiple_fill: true }).where.not(finished_at: nil)
    user_sessions_in_progress = UserSession.where(user_intervention: user_intervention, finished_at: nil, started: true)

    finished_multiple_fill_user_sessions.any? && user_sessions_in_progress.blank?
  end
end
