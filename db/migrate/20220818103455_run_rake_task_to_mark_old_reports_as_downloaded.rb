class RunRakeTaskToMarkOldReportsAsDownloaded < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:mark_reports_as_downloaded'].invoke
  end
end
