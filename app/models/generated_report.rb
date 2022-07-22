# frozen_string_literal: true

class GeneratedReport < ApplicationRecord
  has_paper_trail
  belongs_to :user_session
  belongs_to :report_template
  belongs_to :participant, optional: true, class_name: 'User'

  has_many :generated_reports_third_party_users, dependent: :destroy
  has_many :third_party_users, through: :generated_reports_third_party_users, source: :third_party

  delegate :name, to: :report_template, prefix: true

  scope :for_third_party_user, lambda { |user|
    joins(:generated_reports_third_party_users).where(generated_reports_third_party_users: { third_party_id: user.id })
  }

  has_one_attached :pdf_report

  validates :pdf_report, content_type: %w[application/pdf]

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant'
  }

  def downloaded?(user_id)
    downloaded_report = DownloadedReport.find_by(user_id: user_id, generated_report_id: id)
    downloaded_report.nil? ? false : downloaded_report.downloaded?
  end
end
