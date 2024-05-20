class CreateSmsLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :sms_links, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :url, null: false
      t.string :variable, null: false
      t.string :type, null: false, default: 'website'
      t.references :session, null: false, foreign_key: true, type: :uuid, index: true
      t.references :sms_plan, null: false, foreign_key: true, type: :uuid, index: true
      t.string :entered_timestamps, array: true, null: false, default: []

      t.timestamps
    end
    add_index :sms_links, [:sms_plan_id, :variable], unique: true
  end
end
