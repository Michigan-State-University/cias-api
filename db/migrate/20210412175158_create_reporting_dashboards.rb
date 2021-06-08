# frozen_string_literal: true

class CreateReportingDashboards < ActiveRecord::Migration[6.0]
  def change
    create_table :reporting_dashboards, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :organization_id, index: true, foreign_key: true
      t.timestamps
    end
  end
end
