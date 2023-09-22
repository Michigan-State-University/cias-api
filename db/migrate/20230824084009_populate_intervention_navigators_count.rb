class PopulateInterventionNavigatorsCount < ActiveRecord::Migration[6.1]
  def change
    Intervention.find_each do |intervention|
      Intervention.reset_counters(intervention.id, :navigators)
    end
  end
end
