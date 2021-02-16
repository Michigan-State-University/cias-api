# frozen_string_literal: true

class ReportTemplate < ApplicationRecord
  belongs_to :session, counter_cache: true
  has_one_attached :logo

  validates :name, :report_for, presence: true
  validates :name, uniqueness: { scope: :session_id }

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant'
  }
end
