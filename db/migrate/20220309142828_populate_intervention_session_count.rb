# frozen_string_literal: true

class PopulateInterventionSessionCount < ActiveRecord::Migration[6.1]
  def up
    Intervention.find_each do |intervention|
      Intervention.reset_counters(intervention.id, :sessions)
    end
  end
end
