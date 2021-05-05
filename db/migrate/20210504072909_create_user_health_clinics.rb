class CreateUserHealthClinics < ActiveRecord::Migration[6.0]
  def change
    create_table :user_health_clinics, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, index: true, foreign_key: true
      t.uuid :health_clinic_id, index: true, foreign_key: true

      t.timestamps
    end
  end
end
