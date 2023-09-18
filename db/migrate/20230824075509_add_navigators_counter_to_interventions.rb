class AddNavigatorsCounterToInterventions < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :navigators_count, :integer, default: 0
  end
end
