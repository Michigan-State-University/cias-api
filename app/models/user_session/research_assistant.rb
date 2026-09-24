# frozen_string_literal: true

class UserSession::ResearchAssistant < UserSession
  include ::UserSession::ClassicBehavior

  belongs_to :fulfilled_by, class_name: 'User', optional: true

  def finish(send_email: true, reason: 'completed') # rubocop:disable Lint/UnusedMethodArgument
    return if finished_at

    cancel_timeout_job
    update(finished_at: DateTime.current, finish_reason: reason)
    delete_alternative_answers
    reload
    decrement_audio_usage

    # UserSessionScheduleService#schedule is skipped — RA blocking is handled by
    # PDP verify, not by session scheduling.

    AfterFinishUserSessionJob.perform_later(id, session.intervention, reason)

    return if reason == 'inactivity_timeout'

    V1::SmsPlans::ScheduleSmsForUserSession.call(self)
    V1::ChartStatistics::CreateForUserSession.call(self)
    update_user_intervention(session_is_finished: true)
  end
end
