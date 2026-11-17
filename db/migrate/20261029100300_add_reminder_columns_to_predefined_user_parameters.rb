# frozen_string_literal: true

class AddReminderColumnsToPredefinedUserParameters < ActiveRecord::Migration[8.1]
  def up
    add_column :predefined_user_parameters, :first_opened_at, :datetime unless column_exists?(:predefined_user_parameters, :first_opened_at)
    add_column :predefined_user_parameters, :last_reminder_sent_at, :datetime unless column_exists?(:predefined_user_parameters, :last_reminder_sent_at)

    backfill_first_opened_at
  end

  def down
    remove_column :predefined_user_parameters, :first_opened_at
    remove_column :predefined_user_parameters, :last_reminder_sent_at
  end

  private

  # Participants who opened their personal link before this release count as opened. The earliest non-RA
  # session stands in for the first open; RA sessions are created by bulk import or an RA fill-in before the
  # participant ever clicks.
  def backfill_first_opened_at
    execute(<<~SQL.squish)
      UPDATE predefined_user_parameters AS pup
      SET first_opened_at = opened.first_opened_at
      FROM (
        SELECT user_sessions.user_id, sessions.intervention_id, MIN(user_sessions.created_at) AS first_opened_at
        FROM user_sessions
        INNER JOIN sessions ON sessions.id = user_sessions.session_id
        WHERE user_sessions.type <> 'UserSession::ResearchAssistant'
        GROUP BY user_sessions.user_id, sessions.intervention_id
      ) AS opened
      WHERE pup.user_id = opened.user_id
        AND pup.intervention_id = opened.intervention_id
        AND pup.first_opened_at IS NULL
    SQL
  end
end
