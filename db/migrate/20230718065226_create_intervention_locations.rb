class CreateInterventionLocations < ActiveRecord::Migration[6.1]
  def change
    create_table :intervention_locations, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.belongs_to :intervention, type: :uuid
      t.belongs_to :clinic_location, type: :uuid
      t.timestamps
    end
  end
end
