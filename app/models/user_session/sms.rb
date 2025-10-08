# frozen_string_literal: true

class UserSession::Sms < UserSession
  delegate :first_question, :autofinish_enabled, :autofinish_delay, :questions, to: :session

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
  end
end
