class AddTypeColumnToIntervention < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :type, :string, null: false, default: 'Intervention'
  end
end
