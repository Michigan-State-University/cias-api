# frozen_string_literal: true

class ReportTemplate::Section < ApplicationRecord
  has_paper_trail

  CURRENT_VERSION = '1'

  belongs_to :report_template
  has_many :variants, class_name: 'ReportTemplate::Section::Variant', dependent: :destroy,
                      foreign_key: :report_template_section_id, inverse_of: :report_template_section

  before_create :assign_position

  default_scope { order(:position) }

  ATTR_NAMES_TO_COPY = %w[
    formula
  ].freeze

  def assign_position
    self.position = report_template.sections.count
  end
end
