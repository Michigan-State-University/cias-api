class CreatePredefinedUserParameters < ActiveRecord::Migration[6.1]
  def change
    create_table :predefined_user_parameters, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :slug, null: false
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :intervention, null: false, foreign_key: true, type: :uuid
      t.references :health_clinic, null: true, foreign_key: true, type: :uuid
      t.timestamps
    end
  end
end
