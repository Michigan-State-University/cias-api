# frozen_string_literal: true

class ReportTemplate < ApplicationRecord
  belongs_to :session, counter_cache: true
  has_many :sections, class_name: 'ReportTemplate::Section', dependent: :destroy
  has_many :variants, class_name: 'ReportTemplate::Section::Variant', through: :sections

  has_one_attached :logo
  has_one_attached :pdf_preview

  validates :name, :report_for, presence: true
  validates :name, uniqueness: { scope: :session_id }

  enum report_for: {
    third_party: 'third_party',
    participant: 'participant'
  }
end
