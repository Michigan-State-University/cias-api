class CreateTimeRange < ActiveRecord::Migration[6.1]
  def change
    create_table :time_ranges, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.integer :from, null: false
      t.integer :to, null: false
      t.integer :position, null: false, default: 0
      t.string :label, null: false
      t.boolean :default, null: false, default: false
      t.timestamps
    end
  end
end
