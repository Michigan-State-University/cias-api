# frozen_string_literal: true

class UserSession::ResearchAssistant < UserSession
  include ::UserSession::ClassicBehavior

  belongs_to :fulfilled_by, class_name: 'User', optional: true

  def finish(send_email: true)
    return if finished_at

    cancel_timeout_job
    update(finished_at: DateTime.current)
    delete_alternative_answers
    reload
    decrement_audio_usage

    # RA is outside the participant session flow — two Classic#finish calls are skipped:
    #
    # 1. V1::SmsPlans::ScheduleSmsForUserSession — harmless no-op (RA has no SMS plans),
    #    but skipped for clarity.
    #
    # 2. V1::UserSessionScheduleService#schedule — MUST be skipped. It calls
    #    branch_to_session → session.next_session → finds Classic session at position 1+,
    #    then pre-creates a UserSession for it and may send scheduling emails/links to the
    #    participant BEFORE they've even verified via PDP link. RA blocking is handled by
    #    PDP verify, not by session scheduling.

    V1::ChartStatistics::CreateForUserSession.call(self)
    AfterFinishUserSessionJob.perform_later(id, session.intervention)
    update_user_intervention(session_is_finished: true)
  end
end
