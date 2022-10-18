# frozen_string_literal: true

class AddDefaultNarratorToInterventionsAndSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :current_narrator, :integer, default: 0
    add_column :sessions, :current_narrator, :integer, default: 0
  end
end
