class RemoveOriginalTextFromInterventions < ActiveRecord::Migration[6.0]
  def change
    remove_column :interventions, :original_text, :jsonb
  end
end
