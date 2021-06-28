# frozen_string_literal: true

class AddPositionToDashboardSection < ActiveRecord::Migration[6.0]
  def change
    add_column :dashboard_sections, :position, :integer, default: 1, null: false
  end
end
