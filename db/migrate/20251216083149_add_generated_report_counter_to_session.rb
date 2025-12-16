class AddGeneratedReportCounterToSession < ActiveRecord::Migration[7.2]
  def up
    add_column :sessions, :generated_reports_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        sql = <<-SQL.squish
          UPDATE sessions
          SET generated_reports_count = (
            SELECT COUNT(*)
            FROM generated_reports
            INNER JOIN user_sessions ON user_sessions.id = generated_reports.user_session_id
            WHERE user_sessions.session_id = sessions.id
          )
        SQL

        execute(sql)
      end
    end
  end

  def down
    remove_column :sessions, :generated_reports_count
  end
end
