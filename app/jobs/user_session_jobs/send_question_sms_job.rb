# frozen_string_literal: true

class UserSessionJobs::SendQuestionSmsJob < ApplicationJob
  queue_as :question_sms

  def perform(user_id, question_id, user_session_id, is_alert = false)
    user = User.find(user_id)

    return if !is_alert && !user&.sms_notification

    question = Question.find(question_id)
    user_session = UserSession::Sms.find(user_session_id)

    # Handle case when user has pending answers
    if user.pending_sms_answer
      if question.type.match?('Question::SmsInformation')
        # Handle case with outdated SmsInformation question - reschedule question in 5 minutes till the end of the day
        datetime_of_next_job = DateTime.current + 5.minutes

        # Skip question if next day
        if datetime_of_next_job > question.schedule_at.end_of_day
          V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [] } })
        else
          UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id)
        end
      else
        # Handle case with outdated SMS question - reschedule question in 5 hours for 3 days
        datetime_of_next_job = DateTime.current + 1.day
        unless datetime_of_next_job > question.schedule_at + 3.days
          UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id)
        end
      end
    end

    return if user.pending_sms_answer

    # Handle case with no pending answers, send current question
    send_sms(user.full_number, question.title)

    if question.type.match?('Question::SmsInformation')
      # Create answer and schedule next question
      V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [] } })
      next_question = V1::FlowService::NextQuestion.new(user_session).call(nil)
      UserSessionJobs::SendQuestionSmsJob.set(wait_until: next_question.schedule_at).perform_later(user_id, question_id, user_session_id) if next_question
    else
      # Schedule question followup
      schedule_question_followup(user_id, question_id, user_session_id)
      user.update(pending_sms_answer: true)
    end
  end

  private

  def send_sms(number, content)
    sms = Message.create(phone: number, body: content, attachment_url: nil)
    Communication::Sms.new(sms.id).send_message
  end

  def schedule_question_followup(user_id, question_id, user_session_id)
    UserSessionJobs::SendQuestionSmsJob.set(wait_until: next_question.schedule_at + 1.day).perform_later(user_id, question_id, user_session_id)
    UserSessionJobs::SendQuestionSmsJob.set(wait_until: next_question.schedule_at + 2.days).perform_later(user_id, question_id, user_session_id)
  end
end
