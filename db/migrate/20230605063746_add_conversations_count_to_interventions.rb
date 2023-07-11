class AddConversationsCountToInterventions < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :conversations_count, :integer
  end
end
