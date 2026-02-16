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
    next_user_session = UserSession.find_by(session_id: next_session&.id, user_intervention: user_intervention)

    if next_user_session.blank?
      return nil unless next_session&.available_now?(participant_date_with_payload(user_intervention, next_session))

      return next_session
    end

    return nil if next_user_session.scheduled_at&.future?

    next_session
  end

  def multiple_fill_session_available?(user_intervention)
    finished_multiple_fill_user_sessions = UserSession.joins(:session).where(user_intervention: user_intervention,
                                                                             session: { multiple_fill: true }).where.not(finished_at: nil)
    user_sessions_in_progress = UserSession.where(user_intervention: user_intervention, finished_at: nil, started: true)

    finished_multiple_fill_user_sessions.any? && user_sessions_in_progress.blank?
  end

  private

  def participant_date_with_payload(user_intervention, next_session)
    return nil unless next_session&.schedule == 'days_after_date'

    last_user_session = UserSession.where(user_intervention: user_intervention).where.not(finished_at: nil).order(:last_answer_at).last
    return nil unless last_user_session

    all_var_values = V1::UserInterventionService.new(user_intervention.id, last_user_session.id).var_values(true)
    participant_date = all_var_values[next_session.days_after_date_variable_name]

    return nil unless participant_date

    participant_date.to_datetime + next_session.schedule_payload&.days
  end
end
