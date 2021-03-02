# frozen_string_literal: true

class GeneratedReport < ApplicationRecord
  belongs_to :user_session
  belongs_to :report_template

  has_one_attached :pdf_report

  validates :pdf_report, content_type: %w[application/pdf]

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant'
  }
end
