# frozen_string_literal: true

class ReportTemplate < ApplicationRecord
  has_paper_trail
  belongs_to :session, counter_cache: true
  has_many :sections, class_name: 'ReportTemplate::Section', dependent: :destroy
  has_many :variants, class_name: 'ReportTemplate::Section::Variant', through: :sections
  has_many :generated_reports, dependent: :destroy

  has_one_attached :logo
  has_one_attached :pdf_preview

  validates :name, :report_for, presence: true
  validates :name, uniqueness: { scope: :session_id }

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant'
  }

  ATTR_NAMES_TO_COPY = %w[
    name report_for summary
  ].freeze
end
