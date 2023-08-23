class AddPositionToReportTemplateSectionVariants < ActiveRecord::Migration[6.1]
  def change
    add_column(:report_template_section_variants, :position, :integer, default: 0, null: false)
  end
end
