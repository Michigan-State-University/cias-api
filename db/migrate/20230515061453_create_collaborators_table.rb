class CreateCollaboratorsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :collaborators, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.boolean :view, null: false, default: true
      t.boolean :edit, null: false, default: false
      t.boolean :data_access, null: false , default: false
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :intervention, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end
  end
end
