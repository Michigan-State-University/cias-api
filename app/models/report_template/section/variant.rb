# frozen_string_literal: true

class ReportTemplate::Section::Variant < ApplicationRecord
  has_paper_trail
  extend DefaultValues

  CURRENT_VERSION = '1'

  belongs_to :report_template_section, class_name: 'ReportTemplate::Section'
  has_one_attached :image

  attribute :original_text, :json, default: assign_default_values('original_text')

  validates :image, content_type: %w[image/png image/jpg image/jpeg],
                    size: { less_than: 5.megabytes }

  scope :to_preview, -> { where(preview: true) }

  ATTR_NAMES_TO_COPY = %w[
    preview formula_match title content
  ].freeze

  def translate_title(translator, source_language_name_short, destination_language_name_short)
    original_text['title'] = title
    new_title = translator.translate(title, source_language_name_short, destination_language_name_short)

    update!(title: new_title)
  end

  def translate_content(translator, source_language_name_short, destination_language_name_short)
    original_text['content'] = content
    new_content = translator.translate(content, source_language_name_short, destination_language_name_short)

    update!(content: new_content)
  end

  def translate(translator, source_language_name_short, destination_language_name_short)
    translate_title(translator, source_language_name_short, destination_language_name_short)
    translate_content(translator, source_language_name_short, destination_language_name_short)
  end
end
