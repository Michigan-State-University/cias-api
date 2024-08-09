class AddGoogleLanguageToSessions < ActiveRecord::Migration[6.1]
  def up
    add_reference :sessions, :google_language, foreign_key: true

    execute 'UPDATE sessions SET google_language_id=(SELECT google_language_id FROM interventions WHERE interventions.id=sessions.intervention_id);'
  end

  def down
    remove_column :sessions, :google_language
  end
end
