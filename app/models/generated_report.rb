# frozen_string_literal: true

class GeneratedReport < ApplicationRecord
  belongs_to :user_session
  belongs_to :report_template
  belongs_to :third_party, optional: true, class_name: 'User'
  belongs_to :participant, optional: true, class_name: 'User'

  delegate :name, to: :report_template, prefix: true

  has_one_attached :pdf_report

  validates :pdf_report, content_type: %w[application/pdf]

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant'
  }
end
