# frozen_string_literal: true

class CreateDashboardSections < ActiveRecord::Migration[6.0]
  def change
    create_table :dashboard_sections, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name
      t.string :description
      t.uuid :reporting_dashboard_id, index: true, foreign_key: true

      t.timestamps
    end
  end
end
