class AddShortLinkToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :short_link, :string
    add_index :interventions, :short_link, unique: true
  end
end
