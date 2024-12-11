# frozen_string_literal: true

class UserSessionJobs::SendQuestionSmsJob < ApplicationJob
  queue_as :question_sms

  # rubocop:disable Metrics/PerceivedComplexity
  def perform(user_id, question_id, user_session_id, reminder, postponed = false)
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
      datetime_of_next_job = DateTime.current.in_time_zone(ENV['CSV_TIMESTAMP_TIME_ZONE']) + 5.minutes

      # Skip question if next day
      if datetime_of_next_job < DateTime.current.in_time_zone(ENV['CSV_TIMESTAMP_TIME_ZONE']).end_of_day
        UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id, false, true)
      else
        outdated_message = true
      end
    end

    user.update(pending_sms_answer: false) if outdated_message && postponed
    user_session.update(current_question_id: false) if outdated_message && postponed

    return if (user.pending_sms_answer && question.type == 'Question::Sms') || outdated_message

    # Handle case with no pending answers, send current question
    send_sms(user.full_number, question.subtitle)
    user_session.update!(current_question_id: question.id) if question.type == 'Question::Sms'

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

  def schedule_question_followups(user, question, user_session)
    # Get proper configuration
    every_number_of_hours = question.sms_reminders['per_hours'].to_i
    for_number_of_days = question.sms_reminders['number_of_days'].to_i
    from = ActiveSupport::TimeZone[ENV['CSV_TIMESTAMP_TIME_ZONE']].parse(question.sms_reminders['from'] || '')
    to = ActiveSupport::TimeZone[ENV['CSV_TIMESTAMP_TIME_ZONE']].parse(question.sms_reminders['to'] || '')

    return unless every_number_of_hours && for_number_of_days && from && to

    # Prepare all vars for calculation of all reminders
    reminders_datetimes = [DateTime.current.in_time_zone(ENV['CSV_TIMESTAMP_TIME_ZONE'])]
    calculated_datetime = reminders_datetimes.last
    last_possible_reminder = ActiveSupport::TimeZone[ENV['CSV_TIMESTAMP_TIME_ZONE']].parse(question.sms_reminders['to']) + (for_number_of_days - 1).days

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
