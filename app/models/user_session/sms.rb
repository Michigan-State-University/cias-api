# frozen_string_literal: true

class UserSession::Sms < UserSession
  has_encrypted :sms_phone_number
  blind_index :sms_phone_number

  delegate :first_question, :autofinish_enabled, :autofinish_delay, :questions, to: :session

  def sms_full_number
    return nil if sms_phone_prefix.blank? || sms_phone_number.blank?

    "#{sms_phone_prefix}#{sms_phone_number}"
  end

  def last_answer
    answers.confirmed.unscope(:order).order(:updated_at).last
  end

  def find_current_question
    session
      .question_groups
      .left_joins(:questions)
      .where.not(answer: nil)
      .order('question_groups.position ASC, questions.position ASC')
      .first
  end

  def on_answer; end

  def finish
    return if finished_at

    update(finished_at: DateTime.current)
    UserSessionJobs::SendGoodbyeMessageJob.perform_later(id)
  end
end
