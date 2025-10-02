# frozen_string_literal: true

class UserSessionJobs::SendQuestionSmsJob < ApplicationJob
  queue_as :question_sms

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def perform(user_id, question_id, user_session_id, reminder, postponed = false)
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
    user = User.find(user_id)

    should_return = if user.predefined_user_parameter
                      !user.predefined_user_parameter&.sms_notification
                    else
                      !user.sms_notification
                    end

    return if should_return

    question = Question.find(question_id)
    user_session = UserSession::Sms.find(user_session_id)

    # Handle case when current sending job is reminder - needs to be executed before handling pending answer flag
    send_sms(user.full_number, question.subtitle) if reminder

    return if reminder

    # Handle case when user has pending answers - reschedule sms question in 5 minutes till the end of the day
    outdated_message = false

    if user.pending_sms_answer && question.type == 'Question::Sms'
      datetime_of_next_job = DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)) + 5.minutes

      # Skip question if next day
      if datetime_of_next_job < DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)).end_of_day
        UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id, false, true)
      else
        outdated_message = true
      end
    end

    user.update(pending_sms_answer: false) if outdated_message && postponed
    user_session.update(current_question_id: false) if outdated_message && postponed

    return if (user.pending_sms_answer && question.type == 'Question::Sms') || outdated_message

    # Handle case with no pending answers, send current question
    return if number_of_repetitions_ended?(user_session)

    send_sms(user.full_number, question.subtitle)
    send_finish_message if last_question_in_user_session?(user_session, question)
    user_session.assign_attributes(current_question_id: question.id) if question.type == 'Question::Sms'
    user_session.assign_attributes(number_of_repetitions: (user_session.number_of_repetitions || 0) + 1) if should_increment_number_or_repetition?(question)

    user_session.save!

    if question.type.match?('Question::SmsInformation')
      # Create answer
      V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [{ 'value' => '', 'var' => '' }] } })
    else
      # Set pending answer flag
      user.update(pending_sms_answer: true)
      schedule_question_followups(user, question, user_session)
    end
  end

  private

  def last_question_in_user_session?(user_session, question)
    # CASE A: where we should exhausted questions from the group
    # if max_repetitions(user_session) == user_session.number_of_repetitions - 1 //last iteration
    #   question.question_group.questions.order(:position).last.id.eql?(question.id)
    # else
    #   false
    # end
    # CASE B: when we should send questions only until end of cycle (until next question group scheduled)
    return false unless user_session.session.wdays_of_initial_group.include?((DateTime.current.wday+1).to_s)
    return false if more_msgs_scheduled_for_today?(user_session)

    true
  end

  def send_finish_message
    return if user.pending_sms_answer?

    UserSessionJobs::SendGoodbyeMessageJob.
      set(wait_until: DateTime.now + UserSessionJobs::ScheduleDailyMessagesJob::DELAY_BETWEEN_QUESTIONS_IN_SECONDS.seconds).
      perform_later(user_session.id)
  end

  def more_msgs_scheduled_for_today?(user_session)
    queue = Sidekiq::ScheduledSet.new
    queue.any? do |job|
      job_args = job.args.first
      job_args['job_class'] == 'UserSessionJobs::SendQuestionSmsJob' && job_args['arguments'][2].eql?(user_session.id)
    end
  end

  def number_of_repetitions_ended?(user_session)
    return false if max_repetitions(user_session).zero?

    user_session.number_of_repetitions >= max_repetitions(user_session)
  end

  def max_repetitions(user_session)
    @max_repetitions ||= begin
      initial_question_group = user_session.session.question_group_initial
      return 0 if initial_question_group&.sms_schedule.blank?

      initial_question_group.sms_schedule['number_of_repetitions'].to_i
    end
  end

  def should_increment_number_or_repetition?(question)
    return false unless question.question_group.type.eql?('QuestionGroup::Initial')
    return false unless last_question_in_the_group?(question)

    true
  end

  def last_question_in_the_group?(question)
    question.question_group.questions.order(:position).last.id.eql?(question.id)
  end

  def schedule_question_followups(user, question, user_session)
    # Get proper configuration
    every_number_of_hours = question.sms_reminders['per_hours'].to_i
    for_number_of_days = question.sms_reminders['number_of_days'].to_i
    from = ActiveSupport::TimeZone[ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)].parse(question.sms_reminders['from'] || '')
    to = ActiveSupport::TimeZone[ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)].parse(question.sms_reminders['to'] || '')

    return unless every_number_of_hours && for_number_of_days && from && to

    # Prepare all vars for calculation of all reminders
    reminders_datetimes = [DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil))]
    calculated_datetime = reminders_datetimes.last
    last_possible_reminder = ActiveSupport::TimeZone[ENV.fetch('CSV_TIMESTAMP_TIME_ZONE',
                                                               nil)].parse(question.sms_reminders['to']) + (for_number_of_days - 1).days

    # Calculate all possible datetimes
    while calculated_datetime + every_number_of_hours.hour < last_possible_reminder
      calculated_datetime += every_number_of_hours.hour
      reminders_datetimes << calculated_datetime if calculated_datetime.hour >= from.hour && calculated_datetime.hour < to.hour
    end

    # Remove first element of array, as for calculations we had to add current datetime as first element.
    # If while loop will not be able to add any new datetimes we will end up with empty array
    reminders_datetimes.shift(1)

    # Schedule new SMSes sending jobs
    reminders_datetimes.each do |datetime|
      UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime)
                                         .perform_later(user.id, question.id, user_session.id, true)
    end
  end

  def send_sms(number, content)
    sms = Message.create(phone: number, body: content, attachment_url: nil)
    Communication::Sms.new(sms.id).send_message
  end
end
