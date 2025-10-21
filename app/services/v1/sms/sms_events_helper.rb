# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module SmsEventHelper
  def log_start_session(user_session)
    SmsCampaignEvent.create!(
      event_type: 'user_session_created',
      event_data: {},
      user_session: user_session
    )
  end

  def log_scheduled_daily_message_job(user_session, additional_data = {})
    SmsCampaignEvent.create!(
      event_type: 'scheduled_daily_message_job',
      event_data: additional_data,
      user_session: user_session
    )
  end

  def log_earlier_termination(user_session, reason)
    SmsCampaignEvent.create!(
      event_type: 'user_session_terminated_earlier',
      event_data: { reason: reason },
      user_session: user_session
    )
  end

  def log_daily_messages_job_earlier_termination(user_session, reason)
    SmsCampaignEvent.create!(
      event_type: 'daily_messages_job_terminated_earlier',
      event_data: { reason: reason },
      user_session: user_session
    )
  end

  def log_send_question_sms_job(user_sessions, incoming_params)
    SmsCampaignEvent.create!(
      event_type: 'send_question_sms_job_executed',
      event_data: incoming_params,
      user_session: user_sessions
    )
  end

  def log_reminder_sent(user_session, question)
    SmsCampaignEvent.create!(
      event_type: 'reminder_sent',
      event_data: { question_id: question.id },
      user_session: user_session
    )
  end

  def log_sms_message_sent(user_session, question)
    SmsCampaignEvent.create!(
      event_type: 'sms_message_sent',
      event_data: { question_id: question.id },
      user_session: user_session
    )
  end

  def log_messages_scheduled_today(user_session, question_to_send_today)
    SmsCampaignEvent.create!(
      event_type: 'messages_scheduled_today',
      event_data: { questions: map_questions_to_send(question_to_send_today) },
      user_session: user_session
    )
  end

  def log_user_session_finished(user_session)
    SmsCampaignEvent.create!(
      event_type: 'user_session_finished',
      event_data: {},
      user_session: user_session
    )
  end

  def log_incrementation_of_repetitions(user_session, details)
    SmsCampaignEvent.create!(
      event_type: 'user_session_repetition_incremented',
      event_data: details,
      user_session: user_session
    )
  end

  def log_cancelled_sms_jobs(user_session, details = {})
    SmsCampaignEvent.create!(
      event_type: 'cancelled_sms_jobs',
      event_data: details,
      user_session: user_session
    )
  end

  def log_outdated_message_detected(user_session, details = {})
    SmsCampaignEvent.create!(
      event_type: 'outdated_message_detected',
      event_data: details,
      user_session: user_session
    )
  end

  def log_schedule_question_followups_config(user_session, details = {})
    SmsCampaignEvent.create!(
      event_type: 'schedule_question_followups_params',
      event_data: details,
      user_session: user_session
    )
  end

  def log_reminders_jobs(user_session, details = {})
    SmsCampaignEvent.create!(
      event_type: 'reminder_jobs_scheduled',
      event_data: details,
      user_session: user_session
    )
  end

  def log_set_pending_answer_flag(user_session, details = {})
    SmsCampaignEvent.create!(
      event_type: 'pending_answer_flag_set',
      event_data: details,
      user_session: user_session
    )
  end

  def log_postpone_message_send(user_session, details)
    SmsCampaignEvent.create!(
      event_type: 'message_send_postponed',
      event_data: details,
      user_session: user_session
    )
  end

  def log_received_correct_answer(user_session, details = {})
    SmsCampaignEvent.create!(
      event_type: 'correct_answer_received',
      event_data: details,
      user_session: user_session
    )
  end

  private

  def map_questions_to_send(questions)
    questions.map do |element|
      {
        question_id: element[:question].id,
        time_to_send: element[:time_to_send]
      }
    end
  end
end
# rubocop:enable Metrics/ModuleLength
