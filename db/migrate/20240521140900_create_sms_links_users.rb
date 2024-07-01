class CreateSmsLinksUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :sms_links_users do |t|
      t.string :slug, null: false, unique: true
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :sms_link, null: false, foreign_key: true, type: :uuid
      t.string :entered_timestamps, array: true, null: false, default: []
      t.timestamps
    end
    add_index :sms_links_users, [:sms_link_id, :user_id], unique: true
  end
end
