class RenameIsDuplicatedInReportTemplate < ActiveRecord::Migration[6.1]
  def change
    rename_column(:report_templates, :is_duplicated, :is_duplicated_from_other_session)
  end
end
