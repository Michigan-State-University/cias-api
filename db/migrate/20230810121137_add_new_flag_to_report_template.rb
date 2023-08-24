class AddNewFlagToReportTemplate < ActiveRecord::Migration[6.1]
  def change
    add_column(:report_templates, :duplicated_from_other_session_warning_dismissed, :boolean, null: false, default: false)
  end
end
