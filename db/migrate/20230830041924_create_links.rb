class CreateLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :links, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :url
      t.string :slug
      t.index %i[url slug], unique: true
      t.timestamps
    end
  end
end
