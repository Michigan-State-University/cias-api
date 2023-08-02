class AddIsDuplicatedFlagToReportTemplates < ActiveRecord::Migration[6.1]
  def change
    add_column(:report_templates, :is_duplicated, :boolean, null: false, default: false)
  end
end
