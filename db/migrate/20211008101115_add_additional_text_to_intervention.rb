# frozen_string_literal: true

class AddAdditionalTextToIntervention < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :additional_text, :string, default: ''
    add_column :interventions, :original_text, :jsonb
  end
end
