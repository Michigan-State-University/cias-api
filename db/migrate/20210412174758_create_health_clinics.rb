# frozen_string_literal: true

class CreateHealthClinics < ActiveRecord::Migration[6.0]
  def change
    create_table :health_clinics, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name, null: false
      t.uuid :health_system_id, index: true, foreign_key: true

      t.timestamps
    end
  end
end
