# frozen_string_literal: true

class UserSessionJobs::ScheduleDailyMessagesJob < ApplicationJob
  queue_as :question_sms

  def perform(user_session_id)
    @user_session = UserSession.find(user_session_id)
    @user = @user_session.user
    @session = @user_session.session

    # Proceed job only if Intervention is published
    return unless @user_session.user_intervention.intervention.published?

    # Handle Session autoclose
    should_return = @session.autoclose_at.nil? ? false : @session.autoclose_at > DateTime.current

    @user_session.update(finished_at: @session.autoclose_at) if should_return

    return if should_return

    # Find all accessible question groups
    today_scheduled_question_groups = select_questions_groups_scheduled_for_today

    questions_to_be_send_today = []

    # Find all questions scheduled for today in groups
    today_scheduled_question_groups.each do |question_group|
      questions_per_day = question_group.sms_schedule['questions_per_day'] || 1
      positions_to_be_send = get_positions_to_be_send(question_group, questions_per_day)

      positions_to_be_send.each_with_index do |position, index|
        question = question_group.questions.find_by(position: position)
        time_to_send = calculate_question_sending_time(get_proper_sending_period(@user_session.user_intervention, question_group.sms_schedule),
                                                       questions_per_day, index)
        questions_to_be_send_today << { question: question, time_to_send: time_to_send }
      end
    end

    # Remove all questions, that should be send today, but before job execution
    questions_to_be_send_today.reject! { |elem| elem[:time_to_send] < DateTime.current }

    # Adjust Smses sending times for preventing race condition
    sending_times = questions_to_be_send_today.pluck(:time_to_send)
    should_postpone_any_questions = sending_times.count != sending_times.uniq.count

    if should_postpone_any_questions
      questions_to_be_send_today.each_with_index do |question, index|
        question[:time_to_send] = question[:time_to_send] + (index * 2.seconds)
      end
    end


    # Schedule all sending jobs
    questions_to_be_send_today.each do |elem|
      UserSessionJobs::SendQuestionSmsJob.set(wait_until: elem[:time_to_send])
                                         .perform_later(@user.id, elem[:question].id, @user_session.id, false)
    end

    UserSessionJobs::ScheduleDailyMessagesJob.set(wait_until: DateTime.current.midnight + 1.day)
                                             .perform_later(user_session_id)
  end

  private

  def last_answer_in_question_group(question_group)
    if question_group.sms_schedule['start_from_first_question']
      nil
    else
      @user_session
        .answers
        .includes(question: :question_group)
        .where(question: { question_group: question_group })
        .confirmed
        .unscope(:order)
        .order(:updated_at)
        .last
    end
  end

  def calculate_accessible_question_groups_for_user(scoped_question_groups)
    all_var_values = V1::UserInterventionService.new(@user_session.user_intervention_id, @user_session.id).var_values
    scoped_question_groups.select do |question_group|
      formula = question_group.formulas&.first
      formula ? question_group.exploit_formula(all_var_values, formula['payload'], formula['patterns']) : true
    end
  end

  def select_questions_groups_scheduled_for_today
    accessible_question_groups = calculate_accessible_question_groups_for_user(@session.question_groups.order(:position))
    QuestionGroup.where(id: accessible_question_groups.pluck(:id))
                 .where("sms_schedule -> 'day_of_period' @> '[\"#{DateTime.current.wday}\"]'")
  end

  def calculate_question_sending_time(sms_schedule, questions_per_day, question_index)
    # We need to schedule sms sending time in proper timezone.
    # ENV name is misleading, as it refers to CSV generation, but it contains proper timezone value related to users location.
    if sms_schedule.dig('time', 'exact')
      time_of_message = DateTime.parse(sms_schedule.dig('time', 'exact'))
      DateTime.current.in_time_zone(ENV['CSV_TIMESTAMP_TIME_ZONE'] || @user.time_zone).change({ hour: time_of_message.hour, min: time_of_message.minute })
    else
      from = ActiveSupport::TimeZone[ENV['CSV_TIMESTAMP_TIME_ZONE'] || @user.time_zone].parse(sms_schedule.dig('time', 'range', 'from'))
      to = ActiveSupport::TimeZone[ENV['CSV_TIMESTAMP_TIME_ZONE'] || @user.time_zone].parse(sms_schedule.dig('time', 'range', 'to'))

      period = (to - from) / questions_per_day

      time_range_of_question = (from + (question_index * period))..(from + ((question_index + 1) * period))

      rand(time_range_of_question)
    end
  end

  def get_proper_sending_period(user_intervention, question_group_schedule)
    if user_intervention.phone_answers.any? && !question_group_schedule['overwrite_user_time_settings']
      phone_answer = user_intervention.phone_answers.first
      time_range = phone_answer.migrated_body.dig('data', 0, 'value', 'time_ranges')&.sample

      if time_range
        {
          'time' => {
            'range' => {
              'from' => "#{time_range['from']}:00",
              'to' => "#{time_range['to']}:00"
            }
          }
        }
      else
        question_group_schedule
      end
    else
      question_group_schedule
    end
  end

  def get_positions_to_be_send(question_group, questions_per_day)
    last_answer = last_answer_in_question_group(question_group)
    question_group_questions = question_group.questions.order(position: :asc)
    last_question_index = question_group_questions.last.position
    first_question_index = question_group_questions.first.position
    base_range = (first_question_index..last_question_index).to_a

    question_positions = if !last_answer || last_answer.question.position == last_question_index
                           positions_range = base_range
                           (questions_per_day / base_range.length.to_f).ceil.to_i.times do
                             positions_range += base_range
                           end
                           positions_range
                         elsif last_answer.question.position + questions_per_day > last_question_index
                           from_current_question_range = ((last_answer.question.position + 1)..last_question_index).to_a
                           ((questions_per_day / base_range.length.to_f).ceil - 1).to_i.times do
                             from_current_question_range += base_range
                           end
                           from_current_question_range
                         else
                           ((last_answer.question.position + 1)..last_question_index).to_a
                         end

    question_positions.first(questions_per_day)
  end
end
