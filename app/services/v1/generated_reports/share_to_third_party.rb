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
    return if third_party_emails_report_template_ids.blank?
    return if third_party_users.blank?

    number_of_generated_reports = create_generated_reports_third_party_users
    send_reports_emails(number_of_generated_reports)
  end

  private

  attr_reader :user_session, :third_party_reports

  def send_reports_emails(number_of_generated_reports)
    third_party_users.each do |user|
      next if user.deactivated? || !user.email_notification

      num_of_generated_reports = number_of_generated_reports[user.email]
      if user.confirmed?
        GeneratedReportMailer.new_report_available(user.email, num_of_generated_reports).deliver_now if num_of_generated_reports.positive?
      else
        SendNewReportNotificationJob.set(wait: 30.seconds).perform_later(user.email, num_of_generated_reports)
      end
    end
  end

  def create_generated_reports_third_party_users
    third_party_emails_report_template_ids.each_with_object(Hash.new(0)) do |(emails, report_ids), number_of_generated_reports|
      report_ids.each do |report_template_id|
        generated_report = third_party_reports.find_by(report_template_id: report_template_id)
        next unless generated_report

        third_party_users.each do |user|
          if emails.include?(user.email)
            generated_report.generated_reports_third_party_users.create!(third_party_id: user.id)
            number_of_generated_reports[user.email] += 1
          end
        end
      end
    end
  end

  def third_party_users
    @third_party_users ||= find_or_create_third_party_users.uniq
  end

  def find_or_create_third_party_users
    [].tap do |users|
      third_party_emails_report_template_ids.each do |emails, report_ids|
        emails.each do |email|
          next if email.blank?
          next if report_ids.empty?

          user = User.find_by(email: email)
          next if user.present? && user.not_a_third_party?

          user ||= User.invite!(email: email, roles: ['third_party'])
          users << user
        end
      end
    end
  end

  def third_party_emails_report_template_ids
    # rubocop:disable Layout/LineLength
    # rubocop:disable Style/MultilineBlockChain
    @third_party_emails_report_template_ids ||= Answer::ThirdParty.where(user_session_id: user_session.id)
                                                    .map do |answer|
                                                  [answer.body_data&.first&.dig('value')&.delete(' ')&.split(',').to_a,
                                                   answer.body_data&.first&.dig('report_template_ids')]
                                                end
                                                    .each_with_object({}) { |(k, v), h| h[k] = (h[k] || []) + v } # to get {[email1, email2] => ["report_1_id", "report_2_id"]} from [[[email1, email2], ["report_1_id"]], [[email1, email2], ["report_2_id"]]]
    # rubocop:enable Layout/LineLength
    # rubocop:enable Style/MultilineBlockChain
  end
end
