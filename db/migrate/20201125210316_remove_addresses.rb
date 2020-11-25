# frozen_string_literal: true

class RemoveAddresses < ActiveRecord::Migration[6.0]
  def up
    drop_table :addresses
  end

  def down
    create_table :addresses, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id
      t.string :name
      t.string :country
      t.string :state
      t.string :state_abbreviation
      t.string :city
      t.string :zip_code
      t.string :street
      t.string :building_address
      t.string :apartment_number

      t.timestamps
    end
    add_index :addresses, :user_id

    add_foreign_key :addresses, :users
  end
end
