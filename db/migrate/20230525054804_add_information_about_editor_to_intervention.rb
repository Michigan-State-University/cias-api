class AddInformationAboutEditorToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_reference(:interventions, :current_editor, foreign_key: { to_table: :users }, type: :uuid)
  end
end
