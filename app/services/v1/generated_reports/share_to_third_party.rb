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
    return if third_party_emails.blank?
    return if third_party_users.blank?

    create_generated_reports_third_party_users
    send_reports_emails
  end

  private

  attr_reader :user_session, :third_party_reports

  def send_reports_emails
    third_party_users.each do |user|
      next if user.deactivated? || !user.email_notification

      if user.confirmed?
        GeneratedReportMailer.new_report_available(user.email).deliver_now
      else
        SendNewReportNotificationJob.set(wait: 30.seconds).perform_later(user.email)
      end
    end
  end

  def create_generated_reports_third_party_users
    third_party_reports.each do |report|
      third_party_users.each do |user|
        report.generated_reports_third_party_users.create!(third_party_id: user.id)
      end
    end
  end

  def third_party_users
    @third_party_users ||= find_or_create_third_party_users
  end

  def find_or_create_third_party_users
    [].tap do |users|
      third_party_emails.each do |email|
        next if email.blank?

        user = User.find_by(email: email)
        next if user.present? && user.roles.exclude?('third_party')

        user ||= User.invite!(email: email, roles: ['third_party'])
        users << user
      end
    end
  end

  def third_party_emails
    @third_party_emails ||= Answer::ThirdParty.where(
      user_session_id: user_session.id
    ).map { |answer| answer.body_data&.first&.dig('value') }
  end
end
