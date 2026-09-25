# frozen_string_literal: true

class UserSession::Classic < UserSession
  include ::UserSession::ClassicBehavior

  def finish(send_email: true, reason: 'completed')
    return if finished_at

    cancel_timeout_job
    update(finished_at: DateTime.current, finish_reason: reason)
    delete_alternative_answers
    reload

    decrement_audio_usage

    AfterFinishUserSessionJob.perform_later(id, session.intervention, reason)

    return if reason == 'inactivity_timeout'

    V1::SmsPlans::ScheduleSmsForUserSession.call(self)
    V1::UserSessionScheduleService.new(self).schedule if send_email
    V1::ChartStatistics::CreateForUserSession.call(self)

    update_user_intervention(session_is_finished: true)
  end
end
