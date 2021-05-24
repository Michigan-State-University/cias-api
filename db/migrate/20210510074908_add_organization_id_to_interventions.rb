# frozen_string_literal: true

class AddOrganizationIdToInterventions < ActiveRecord::Migration[6.0]
  def change
    add_reference :interventions, :organization, foreign_key: true, type: :uuid
  end
end
