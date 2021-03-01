# frozen_string_literal: true

class ReportTemplate::Section::Variant < ApplicationRecord
  belongs_to :report_template_section, class_name: 'ReportTemplate::Section'
  has_one_attached :image

  validates :image, content_type: %w[image/png image/jpg image/jpeg],
                    size: { less_than: 5.megabytes }

  scope :to_preview, -> { where(preview: true) }
end
