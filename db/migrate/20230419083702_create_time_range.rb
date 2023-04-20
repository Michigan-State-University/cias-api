class CreateTimeRange < ActiveRecord::Migration[6.1]
  def change
    create_table :time_ranges, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.numeric :from, null: false
      t.numeric :to, null: false
      t.numeric :position, null: false, default: 0
      t.timestamps
    end
  end
end
