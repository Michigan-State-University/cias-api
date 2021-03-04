# frozen_string_literal: true

class V1::GeneratedReports::ShareToThirdParty
  def self.call(report, user_session)
    new(report, user_session).call
  end

  def initialize(report, user_session)
    @report = report
    @user_session = user_session
  end

  def call
    return unless report.third_party?
    return if third_party_email.blank?
    return if user_is_not_third_party?
    return if user_deactivated?

    if user.blank?
      third_party = User.invite!(email: third_party_email, roles: ['third_party'])
      report.update!(third_party_id: third_party.id)
    else
      report.update!(third_party_id: user.id)
      GeneratedReportMailer.new_report_available(user.email).deliver_now
    end
  end

  private

  attr_reader :user_session, :report

  def user
    @user ||= User.find_by(email: third_party_email)
  end

  def user_is_not_third_party?
    user&.not_a_third_party?
  end

  def user_deactivated?
    user&.deactivated?
  end

  def third_party_email
    @third_party_email ||= Answer.find_by(
      type: 'Answer::ThirdParty',
      user_session_id: user_session.id
    )&.body_data&.first&.dig('value')
  end
end
