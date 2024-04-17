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
      # Handle case with outdated question - reschedule question in 5 minutes till the end of the day
      datetime_of_next_job = DateTime.current + 5.minutes

      # Skip question if next day
      if datetime_of_next_job > question.schedule_in(user_session).end_of_day
        if question.type.match?('Question::SmsInformation')
          V1::AnswerService.call(user,
                                 user_session.id,
                                 question.id,
                                 { type: 'Answer::SmsInformation',
                                   body: { data: [] } })
        else
          V1::AnswerService.call(user,
                                 user_session.id,
                                 question.id,
                                 { type: 'Answer::Sms',
                                   body: { data: [{ value: '', var: question.body['variable']['name'] }] } })
        end
      else
        UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id)
      end
    end

    return if user.pending_sms_answer

    # Handle case with no pending answers, send current question
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
      # Set pending answer flag
      user.update(pending_sms_answer: true)
    end
  end

  private

  def send_sms(number, content)
    sms = Message.create(phone: number, body: content, attachment_url: nil)
    Communication::Sms.new(sms.id).send_message
  end
end
