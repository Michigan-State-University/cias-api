# frozen_string_literal: true

class UserSessionJobs::ScheduleDailyMessagesJob < ApplicationJob
  queue_as :question_sms

  def perform(user_session_id)
    user_session = UserSession.find(user_session_id)
    user = user_session.user
    session = user_session.session

    # Find all accessible question groups
    accessible_question_groups = calculate_accessible_question_groups_for_user(session.question_groups.order(:position), user_session)
    today_scheduled_question_groups = select_questions_groups_scheduled_for_today(accessible_question_groups)

    questions_to_be_send_today = []

    # Find all questions scheduled for today
    today_scheduled_question_groups.each do |question_group|
      last_answer = last_answer_in_question_group(question_group)
      questions_per_day = question_group.sms_schedule['questions_per_day'] || 1
      last_question_index = question_group.questions.order(position: :desc).first.pluck(:position)

      question_positions = if last_answer.question.position == last_question_index
                             (0..last_question_index)
                           elsif last_answer.question.position + questions_per_day > last_question_index
                             ((last_answer.question.position + 1)..last_question_index).to_a + (0..last_question_index).to_a
                           else
                             ((last_answer.question.position + 1)..last_question_index).to_a
                           end

      positions_to_be_send = question_positions.first(questions_per_day)

      positions_to_be_send.each_with_index do |position, index|
        question = question_group.questions.find_by(position: position)
        time_to_send = calculate_question_sending_time(question_group.sms_schedule, questions_per_day, index)
        questions_to_be_send_today << { question: question, time_to_send: time_to_send }
      end
    end

    # Remove all Information questions if there is any question requiring attention
    any_answer_expected = questions_to_be_send_today.map { |elem| elem[:question].type }.include?('Question::Sms')
    questions_to_be_send_today.reject! { |elem| elem[:question].type.match('Question::SmsInformation') } if any_answer_expected

    # Remove all questions, that should be send today, but before job execution
    questions_to_be_send_today.reject! { |elem| elem[:time_to_send] < DateTime.current }

    # Schedule all sending jobs
    questions_to_be_send_today.each do |elem|
      UserSessionJobs::SendQuestionSmsJob.set(wait_until: elem[:time_to_send])
                                         .perform_later(user.id, elem[:question].id, user_session.id)
    end

    # Schedule next job if Intervention is published
    return unless user_session.user_intervention.intervention.published?

    UserSessionJobs::ScheduleDailyMessagesJob.set(wait_until: DateTime.current.midnight + 1.day)
                                             .perform_later(user_session_id)
  end

  private

  def last_answer_in_question_group(question_group)
    user_session
      .answers
      .includes(question: :question_group)
      .where(question: { question_group: question_group })
      .confirmed
      .unscope(:order)
      .order(:updated_at)
      .last
  end

  def calculate_accessible_question_groups_for_user(scoped_question_groups, user_session)
    all_var_values = V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
    scoped_question_groups.select do |question_group|
      formula = question_group.formulas.first
      question_group.exploit_formula(all_var_values, formula['payload'], formula['patterns'])
    end
  end

  def select_questions_groups_scheduled_for_today(question_groups)
    question_groups.where("sms_schedule ->> 'period' = 'weekly' AND sms_schedule -> 'day_of_period' @> '[\"#{DateTime.current.wday}\"]'")
  end

  def calculate_question_sending_time(sms_schedule, questions_per_day, question_index)
    if sms_schedule['time']['exact']
      DateTime.parse(sms_schedule['time']['exact'])
    else
      from = DateTime.parse(sms_schedule['time']['range']['from'])
      to = DateTime.parse(sms_schedule['time']['range']['to'])

      period = (to - from) / questions_per_day

      time_range_of_question = (from + question_index * period)..(from + (question_index + 1) * period)

      rand(time_range_of_question)
    end
  end
end
