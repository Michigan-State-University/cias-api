class CreateTagsTable < ActiveRecord::Migration[7.2]
  def change
    create_table :tags, id: :uuid, default: 'uuid_generate_v4()' do |t|tables
      t.string :name, null: false
      t.timestamps
    end

    add_index :tags, :name, unique: true
  end
end
