# frozen_string_literal: true

class ReportTemplate < ApplicationRecord
  include Translate
  has_paper_trail
  extend DefaultValues

  belongs_to :session, counter_cache: true
  has_many :sections, class_name: 'ReportTemplate::Section', dependent: :destroy
  has_many :variants, class_name: 'ReportTemplate::Section::Variant', through: :sections
  has_many :generated_reports, dependent: :destroy

  attribute :original_text, :json, default: assign_default_values('original_text')

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

  def translate_summary(translator, source_language_name_short, destination_language_name_short)
    original_text['summary'] = summary
    new_summary = translator.translate(summary, source_language_name_short, destination_language_name_short)

    update!(summary: new_summary)
  end

  def translate_name(translator, source_language_name_short, destination_language_name_short)
    original_text['name'] = name
    new_name = translator.translate(name, source_language_name_short, destination_language_name_short)

    update!(name: new_name)
  end

  def translate_section_variants(translator, source_language_name_short, destination_language_name_short)
    sections.each do |section|
      section.variants.each do |variant|
        variant.translate(translator, source_language_name_short, destination_language_name_short)
      end
    end
  end
end
