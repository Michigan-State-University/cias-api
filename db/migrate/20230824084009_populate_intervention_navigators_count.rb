class PopulateInterventionNavigatorsCount < ActiveRecord::Migration[6.1]
  class AuxiliaryIntervention < ApplicationRecord
    self.table_name = 'interventions'
  end

  def change
    AuxiliaryIntervention.find_each do |intervention|
      AuxiliaryIntervention.reset_counters(intervention.id, :navigators)
    end
  end
end
