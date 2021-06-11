# frozen_string_literal: true

class AddGoogleLanguageToInterventions < ActiveRecord::Migration[6.0]
  def change
    add_reference :interventions, :google_language, null: true, foreign_key: true
  end
end
