# frozen_string_literal: true

class AddDefaultStatusValueToIntervention < ActiveRecord::Migration[6.0]
  def change
    change_column :interventions, :status, :string, default: :draft
  end
end
