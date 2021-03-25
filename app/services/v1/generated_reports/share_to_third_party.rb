# frozen_string_literal: true

class V1::GeneratedReports::ShareToThirdParty
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session        = user_session
    @third_party_reports = user_session.generated_reports.third_party
  end

  def call
    return if third_party_reports.blank?
    return if third_party_email.blank?
    return if user_is_not_third_party?

    third_party_user = find_or_create_third_party

    third_party_reports.update_all(third_party_id: third_party_user.id)

    return if third_party_user&.deactivated?
    return unless third_party_user.email_notification

    if third_party_user.confirmed?
      GeneratedReportMailer.new_report_available(third_party_user.email).deliver_now
    else
      SendNewReportNotificationJob.set(wait: 30.seconds)
        .perform_later(third_party_user.email)
    end
  end

  private

  attr_reader :user_session, :third_party_reports

  def find_or_create_third_party
    user || User.invite!(email: third_party_email, roles: ['third_party'])
  end

  def user
    @user ||= User.find_by(email: third_party_email)
  end

  def user_is_not_third_party?
    user&.not_a_third_party?
  end

  def third_party_email
    @third_party_email ||= Answer.find_by(
      type: 'Answer::ThirdParty',
      user_session_id: user_session.id
    )&.body_data&.first&.dig('value')
  end
end
