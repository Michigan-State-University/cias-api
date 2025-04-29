class PopulateInterventionConversationsCount < ActiveRecord::Migration[6.1]
  class AuxiliaryIntervention < ApplicationRecord
    self.table_name = 'interventions'
  end

  def up
    AuxiliaryIntervention.find_each do |intervention|
      AuxiliaryIntervention.reset_counters(intervention.id, :conversations)
    end
  end
end
