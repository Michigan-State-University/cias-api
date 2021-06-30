# frozen_string_literal: true

class AddGoogleLanguageToInterventions < ActiveRecord::Migration[6.0]
  Rake::Task['google_languages:fetch'].invoke

  def change
    add_reference :interventions, :google_language, null: false, foreign_key: true, default: 22
  end
end
