class CreateHealthSystems < ActiveRecord::Migration[6.0]
  def change
    create_table :health_systems, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name, null: false
      t.uuid :organization_id, index: true, foreign_key: true

      t.timestamps
    end
  end
end
