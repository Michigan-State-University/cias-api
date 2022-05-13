# frozen_string_literal: true

class RemoveFriendlyIdSlugs < ActiveRecord::Migration[6.0]
  def up
    drop_table :friendly_id_slugs
    remove_column :sessions, :slug
  end

  def down
    create_table :friendly_id_slugs, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :slug, null: false
      t.uuid :sluggable_id, null: false
      t.string :sluggable_type, limit: 50
      t.string :scope
      t.datetime :created_at
    end
    add_index :friendly_id_slugs, %i[sluggable_type sluggable_id], using: :gin
    add_index :friendly_id_slugs, %i[slug sluggable_type], using: :gin, length: { slug: 140, sluggable_type: 50 }
    add_index :friendly_id_slugs, %i[slug sluggable_type scope], length: { slug: 70, sluggable_type: 50, scope: 70 },
                                                                 unique: true

    add_column :sessions, :slug, :string
    add_index :sessions, :slug, unique: true
  end
end
