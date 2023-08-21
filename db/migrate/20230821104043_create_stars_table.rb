class CreateStarsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :stars, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, null: false
      t.uuid :intervention_id, null: false
    end

    add_index :stars, :user_id
    add_index :stars, :intervention_id
    add_index :stars, %i[user_id intervention_id], unique: true

    add_foreign_key :stars, :users
    add_foreign_key :stars, :interventions
  end
end
