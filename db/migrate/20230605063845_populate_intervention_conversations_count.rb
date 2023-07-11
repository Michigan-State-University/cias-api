class PopulateInterventionConversationsCount < ActiveRecord::Migration[6.1]
  def up
    Intervention.find_each do |intervention|
      Intervention.reset_counters(intervention.id, :conversations)
    end
  end
end
