# frozen_string_literal: true

class AddIndexToHealthSystem < ActiveRecord::Migration[6.0]
  def change
    add_index :health_systems, [:name, :organization_id], unique: true
  end
end
