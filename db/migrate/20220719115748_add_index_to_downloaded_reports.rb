class AddIndexToDownloadedReports < ActiveRecord::Migration[6.1]
  def change
    add_index(:downloaded_reports, [:user_id, :generated_report_id])
  end
end
