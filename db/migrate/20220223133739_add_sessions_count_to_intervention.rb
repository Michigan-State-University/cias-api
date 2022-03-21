class AddSessionsCountToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :sessions_count, :integer
  end
end
