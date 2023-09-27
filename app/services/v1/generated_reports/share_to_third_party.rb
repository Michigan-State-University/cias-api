# frozen_string_literal: true

class V1::GeneratedReports::ShareToThirdParty
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
    @third_party_reports = user_session.generated_reports.third_party
    @third_party_emails_report_template_ids = Hash.new([])
    @third_party_faxes_report_template_ids = Hash.new({})
    third_party_emails_or_faxes_report_template_ids
  end

  def call
    return if third_party_reports.blank?
    return if no_one_to_send?

    number_of_generated_reports = create_generated_reports_third_party_users
    send_reports_emails(number_of_generated_reports)
    send_faxes
  end

  private

  attr_reader :user_session, :third_party_reports
  attr_accessor :third_party_emails_report_template_ids, :third_party_faxes_report_template_ids

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

  def send_faxes
    documo = Api::Documo.new
    third_party_faxes_report_template_ids.each do |receiver_label, hash|
      hash[:reports].uniq.each do |report_template_id|
        generated_report = third_party_reports.find_by(report_template_id: report_template_id)
        report_template = generated_report.report_template
        fields = report_template.slice(:cover_letter_description, :cover_letter_sender,
                                       :name).merge({ receiver: ActionView::Base.full_sanitizer.sanitize(receiver_label) })
        logo = if report_template.report_logo?
                 report_template.logo
               elsif report_template.custom?
                 report_template.cover_letter_custom_logo
               end
        documo.send_faxes(hash[:numbers].uniq, [generated_report.pdf_report], report_template.has_cover_letter, fields, logo)
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

          email = email.downcase
          user = User.find_by(email: email)
          next if user.present? && user.not_a_third_party?

          user ||= User.invite!(email: email, roles: ['third_party'])
          users << user
        end
      end
    end
  end

  def third_party_emails_or_faxes_report_template_ids
    extracted_data_from_answers.filter(&:all?).each do |faxes_and_emails, rep_id, receiver_label|
      next unless rep_id.instance_of?(Array)

      emails, faxes = faxes_and_emails.partition { |value| valid_email?(value) }

      third_party_emails_report_template_ids[emails] += rep_id if emails.any?
      next unless faxes.any?

      third_party_faxes_report_template_ids[receiver_label] = Hash.new([]) if third_party_faxes_report_template_ids[receiver_label].blank?
      third_party_faxes_report_template_ids[receiver_label][:reports] += rep_id
      third_party_faxes_report_template_ids[receiver_label][:numbers] += faxes
    end
  end

  def valid_email?(email)
    (email =~ URI::MailTo::EMAIL_REGEXP)&.zero?
  end

  def extracted_data_from_answers
    @extracted_data_from_answers ||= Answer::ThirdParty.where(user_session_id: user_session.id).map do |answer|
      [
        answer.body_data&.first&.dig('value')&.delete(' ')&.split(','),
        answer.body_data&.first&.dig('report_template_ids'),
        answer.question.body['data'][answer.body_data.first['index']]['payload'].to_s
      ] # [[email1, fax1, ...], [rep_id], receiver_label]
    end
  end

  def no_one_to_send?
    (third_party_emails_report_template_ids.blank? || third_party_users.blank?) && third_party_faxes_report_template_ids.blank?
  end
end
