# frozen_string_literal: true

class ReportTemplate::Section < ApplicationRecord
  belongs_to :report_template
  has_many :variants, class_name: 'ReportTemplate::Section::Variant', dependent: :destroy,
                      foreign_key: :report_template_section_id, inverse_of: :report_template_section
end
