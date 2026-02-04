class AddNoteToIntervention < ActiveRecord::Migration[7.2]
  def change
    add_column :interventions, :note, :string
  end
end
