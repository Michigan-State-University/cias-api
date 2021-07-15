# frozen_string_literal: true

class AddOriginalTextToReportTemplateSectionVariants < ActiveRecord::Migration[6.0]
  def change
    add_column :report_template_section_variants, :original_text, :jsonb
  end
end
