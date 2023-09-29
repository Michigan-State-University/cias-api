class AddInformationAboutMultipleSession < ActiveRecord::Migration[6.1]
  def change
    add_column :user_sessions, :multiple_fill, :boolean

    execute(<<-SQL.squish)
        UPDATE user_sessions
        SET multiple_fill = (
          SELECT sessions.multiple_fill
          FROM sessions
          WHERE sessions.id = user_sessions.session_id
        );
    SQL

    add_index :user_sessions, [:user_id, :session_id], where: "(created_at > '#{DateTime.now.utc.to_s}'::timestamp) AND multiple_fill IS False"
  end
end
