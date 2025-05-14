# frozen_string_literal: true

class ReportTemplate::Section::Variant < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include ::TranslationAuxiliaryMethods

  CURRENT_VERSION = '1'

  belongs_to :report_template_section, class_name: 'ReportTemplate::Section'
  has_one_attached :image

  attribute :original_text, :json, default: -> { assign_default_values('original_text') }

  after_create :assign_next_position

  validates :image, content_type: %w[image/png image/jpeg],
                    size: { less_than: 5.megabytes }

  scope :to_preview, -> { where(preview: true) }
  default_scope { order(:position) }

  ATTR_NAMES_TO_COPY = %w[
    preview formula_match title content
  ].freeze

  def translate_title(translator, source_language_name_short, destination_language_name_short)
    translate_attribute('title', title, translator, source_language_name_short, destination_language_name_short)
  end

  def translate_content(translator, source_language_name_short, destination_language_name_short)
    translate_attribute('content', content, translator, source_language_name_short, destination_language_name_short)
  end

  def translate(translator, source_language_name_short, destination_language_name_short)
    translate_title(translator, source_language_name_short, destination_language_name_short)
    translate_content(translator, source_language_name_short, destination_language_name_short)
  end

  def assign_next_position
    self.position = report_template_section.variants.count - 1
  end
end
