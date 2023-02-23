class ShortLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :short_links, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.references :linkable, type: :uuid, null: false, polymorphic: true
      t.references :health_clinic, type: :uuid, null: true
      t.string :name, null: false
      t.index :name, unique: true
    end
  end
end
