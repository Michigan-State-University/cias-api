class CreateClinicLocations < ActiveRecord::Migration[6.1]
  def change
    create_table :clinic_locations, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :department, null: false
      t.string :name, null: false
      t.timestamps
    end
  end
end
