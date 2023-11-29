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

    change_column :user_sessions, :multiple_fill, :boolean, null: false, default: false

    add_index :user_sessions, [:user_id, :session_id], where: "(created_at > '2023-10-25 05:30:04'::timestamp) AND multiple_fill IS False", unique: true
  end
end
