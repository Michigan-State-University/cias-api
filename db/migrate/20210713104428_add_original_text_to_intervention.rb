# frozen_string_literal: true

class AddOriginalTextToIntervention < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :original_text, :jsonb
  end
end
