# frozen_string_literal: true

class AddIndexToDashboardSection < ActiveRecord::Migration[6.0]
  def change
    add_index :dashboard_sections, [:name, :reporting_dashboard_id], unique: true
  end
end
