# frozen_string_literal: true

class UserSessionJobs::SendQuestionSmsJob < ApplicationJob
  queue_as :question_sms

  def perform(user_id, question_id, user_session_id, is_alert = false)
    user = User.find(user_id)

    return if !is_alert && !user&.sms_notification

    question = Question.find(question_id)
    user_session = UserSession::Sms.find(user_session_id)

    # Handle case when user has pending answers - reschedule question in 5 minutes till the end of the day
    if user.pending_sms_answer
      datetime_of_next_job = DateTime.current + 5.minutes

      # Skip question if next day
      unless datetime_of_next_job > DateTime.current.end_of_day
        UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id)
      end
    end

    return if user.pending_sms_answer

    # Handle case with no pending answers, send current question
    send_sms(user.full_number, question.subtitle)
    user_session.update!(current_question_id: question.uuid)

    if question.type.match?('Question::SmsInformation')
      # Create answer
      V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [] } })
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