class CreateStarsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :stars, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :intervention, null: false, foreign_key: true, type: :uuid
      t.index %w[user_id intervention_id], unique: true
    end
  end
end
