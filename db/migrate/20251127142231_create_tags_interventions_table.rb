class CreateTagsInterventionsTable < ActiveRecord::Migration[7.2]
  def change
    create_table :tag_interventions, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.references :tag, null: false, foreign_key: true, type: :uuid
      t.references :intervention, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :tag_interventions, [:tag_id, :intervention_id], unique: true
  end
end
