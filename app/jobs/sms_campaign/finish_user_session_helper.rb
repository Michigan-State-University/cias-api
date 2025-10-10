# frozen_string_literal: true

module SmsCampaign::FinishUserSessionHelper
  def finish_user_session_if_that_was_last_question(user_session, question)
    return if question.type.eql?('Question::Sms')
    return unless number_of_repetitions_reached?(user_session)

    initial_question_group = user_session.session.question_group_initial
    is_last_question = number_of_messages_sent_in_last_cycle(user_session) >= expected_number_of_message_in_last_cycle(initial_question_group)
    user_session.finish if is_last_question
  end

  def number_of_repetitions_reached?(user_session)
    return true if user_session.max_repetitions_reached_at.present?

    initial_group = user_session.session.question_group_initial
    return false if initial_group&.sms_schedule.blank?

    max_repetitions = initial_group.sms_schedule['number_of_repetitions'].to_i
    return false if max_repetitions.zero?

    user_session.number_of_repetitions >= max_repetitions
  end

  def expected_number_of_message_in_last_cycle(initial_question_group)
    initial_question_group.sms_schedule['messages_after_limit'].to_i
  end

  def number_of_messages_sent_in_last_cycle(user_session)
    number_of_messages_sent_in_last_cycle ||= Message
      .where(
        question_id: user_session.session.questions.select(:id),
        created_at: user_session.max_repetitions_reached_at..Time.current
      )
      .distinct
      .count(:question_id)
  end

  def was_last_question_in_user_session?(user_session)
    return false unless number_of_repetitions_reached?(user_session)

    initial_question_group = user_session.session.question_group_initial
    number_of_messages_sent_in_last_cycle(user_session) >= expected_number_of_message_in_last_cycle(initial_question_group)
  end
end
