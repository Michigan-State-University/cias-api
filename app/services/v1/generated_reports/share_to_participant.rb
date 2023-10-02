# frozen_string_literal: true

class V1::GeneratedReports::ShareToParticipant
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session        = user_session
    @participant_reports = user_session.generated_reports.participant
  end

  def call
    return if participant_reports.blank?
    return if participant_should_not_receive_report?
    return if session_user.role?('guest') && participant_email.blank?
    return if participant.blank?

    participant_reports.update_all(
      participant_id: participant.id
    )
    return unless participant.email_notification

    if participant.confirmed?
      GeneratedReportMailer.with(locale: user_session.session.language_code).new_report_available(participant.email).deliver_now
    else
      SendNewReportNotificationJob.set(wait: 30.seconds).with(locale: user_session.session.language_code)
        .perform_later(participant.email, user_session.session.language_code)
    end
  end

  private

  attr_reader :participant_reports, :user_session

  def participant_should_not_receive_report?
    return true if participant_report_answer.blank?

    participant_report_answer.body_data.first&.dig('value', 'receive_report').blank?
  end

  def participant_email
    @participant_email ||= participant_report_answer.body_data.first&.dig('value', 'email')
  end

  def participant
    @participant ||=
      if session_user.role?('guest')
        find_or_invite_participant
      elsif session_user.role?('participant')
        session_user
      end
  end

  def find_or_invite_participant
    user = User.find_by(email: participant_email)
    if user.blank?
      User.invite!(roles: ['participant'], email: participant_email)
    elsif user.role?('participant')
      user
    end
  end

  def participant_report_answer
    @participant_report_answer ||= Answer.find_by(
      type: 'Answer::ParticipantReport',
      user_session_id: user_session.id
    )
  end

  def session_user
    @session_user ||= user_session.user
  end
end
