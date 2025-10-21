# frozen_string_literal: true

require_relative '../../services/v1/sms/sms_events_helper'

class UserSessionJobs::SendQuestionSmsJob < ApplicationJob
  include SmsEventHelper
  include SmsCampaign::FinishUserSessionHelper

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

    user_session = UserSession::Sms.find(user_session_id)

    log_send_question_sms_job(
      user_session,
      {
        user_id: user_id,
        question_id: question_id,
        reminder: reminder,
        postponed: postponed
      }
    )

    if should_return
      log_daily_messages_job_earlier_termination(
        user_session,
        { sms_notification: !should_return }
      )
      return
    end

    question = Question.find(question_id)

    # Handle case when current sending job is reminder - needs to be executed before handling pending answer flag
    if reminder
      send_sms(user.full_number, question)
      log_reminder_sent(user_session, question)
      return
    end

    # Handle case when user has pending answers - reschedule sms question in 5 minutes till the end of the day
    outdated_message = false

    if user.pending_sms_answer && question.type == 'Question::Sms'
      datetime_of_next_job = DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)) + 5.minutes

      # Skip question if next day
      if datetime_of_next_job < DateTime.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', nil)).end_of_day
        UserSessionJobs::SendQuestionSmsJob.set(wait_until: datetime_of_next_job).perform_later(user_id, question_id, user_session_id, false, true)
        log_postpone_message_send(user_session, { question_id: question_id, rescheduled_to: datetime_of_next_job })
      else
        outdated_message = true
        log_outdated_message_detected(user_session, { question_id: question_id })
      end
    end

    user.update(pending_sms_answer: false) if outdated_message && postponed
    user_session.update(current_question_id: false) if outdated_message && postponed

    if (user.pending_sms_answer && question.type == 'Question::Sms') || outdated_message
      log_daily_messages_job_earlier_termination(
        user_session,
        {
          pending_sms_answer: user.pending_sms_answer,
          outdated_message: outdated_message,
          question: { id: question_id, type: question.type }
        }
      )
      return
    end

    # Handle case with no pending answers, send current question

    send_sms(user.full_number, question)
    log_sms_message_sent(user_session, question)
    finish_user_session_if_that_was_last_question(user_session, question)
    user_session.assign_attributes(current_question_id: question.id) if question.type == 'Question::Sms'
    if should_increment_number_or_repetition?(question)
      user_session.assign_attributes(number_of_repetitions: (user_session.number_of_repetitions || 0) + 1)
      log_incrementation_of_repetitions(
        user_session,
        { number_of_repetition_after_update: user_session.number_of_repetitions }
      )
    end

    user_session.save!

    if question.type.match?('Question::SmsInformation')
      # Create answer
      V1::AnswerService.call(user, user_session.id, question.id, { type: 'Answer::SmsInformation', body: { data: [{ 'value' => '', 'var' => '' }] } })
    else
      # Set pending answer flag
      user.update(pending_sms_answer: true)
      log_set_pending_answer_flag(user_session, { question_id: question.id })
      schedule_question_followups(user, question, user_session)
    end
  end

  private

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
    log_schedule_question_followups_config(
      user_session,
      {
        every_number_of_hours: every_number_of_hours,
        for_number_of_days: for_number_of_days,
        from: from,
        to: to
      }
    )

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
    log_reminders_jobs(
      user_session,
      {
        reminders_datetimes: reminders_datetimes.shift(1),
        question_id: question.id
      }
    )
  end

  def send_sms(number, question)
    sms = Message.create(phone: number, body: question.subtitle, attachment_url: nil, question: question)
    Communication::Sms.new(sms.id).send_message
  end
end
