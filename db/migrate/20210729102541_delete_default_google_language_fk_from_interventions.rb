class DeleteDefaultGoogleLanguageFkFromInterventions < ActiveRecord::Migration[6.0]
  def change
    change_column_default :interventions, :google_language_id, nil
  end
end
