# frozen_string_literal: true

class UserSessionJobs::SendRecurringSmsJob < ApplicationJob
  queue_as :question_sms

  def perform(user_id, question_id, user_session_id, is_alert = false)
    user = User.find(user_id)

    return if !is_alert && !user&.sms_notification

    question = Question.find(question_id)
    user_session = UserSession::Sms.find(user_session_id)

    send_sms(user.full_number, question.subtitle)
    user_session.update!(current_question_id: question.uuid)

    if question.type.match?('Question::SmsInformation')
      # Create answer and schedule next question
      V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [] } })
      next_question = V1::FlowService::NextQuestion.new(user_session).call(nil)
      if next_question
        UserSessionJobs::SendQuestionSmsJob.set(wait_until: next_question.schedule_in(user_session))
                                           .perform_later(user_id, question_id, user_session_id)
      end
    else
      # Schedule followups if user session has only one answer - it means only initial message
      if user_session.answers.count == 1
        schedule_question_followups(user_id, question_id, user_session_id)
      else
        UserSessionJobs::SendReccuringSmsJob.set(wait_until: question.schedule_in(user_session)).perform_later(user.id, question.id, user_session.id)
      end
      # Set pending answer flag
      user.update(pending_sms_answer: true)
    end
  end

  private

  def send_sms(number, content)
    sms = Message.create(phone: number, body: content, attachment_url: nil)
    Communication::Sms.new(sms.id).send_message
  end

  def schedule_question_followups(user_id, question_id, user_session_id)
    UserSessionJobs::SendRecurringSmsJob.set(wait_until: next_question.schedule_at + 1.day).perform_later(user_id, question_id, user_session_id)
    UserSessionJobs::SendRecurringSmsJob.set(wait_until: next_question.schedule_at + 2.days).perform_later(user_id, question_id, user_session_id)
  end
end
