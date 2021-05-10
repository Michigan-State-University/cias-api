# frozen_string_literal: true

class CreateChartStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :chart_statistics, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :label
      t.uuid :organization_id, null: false, foreign_key: true
      t.uuid :health_system_id, null: false, foreign_key: true
      t.uuid :health_clinic_id, null: false, foreign_key: true
      t.uuid :chart_id, null: false, foreign_key: true
      t.uuid :user_id, null: false, foreign_key: true

      t.timestamps
    end
  end
end
