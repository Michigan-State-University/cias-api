class CreateBulkImportPayloads < ActiveRecord::Migration[7.2]
  def change
    create_table :bulk_import_payloads, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.references :researcher, type: :uuid, null: false,
                                foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :intervention, type: :uuid, null: false,
                                  foreign_key: { on_delete: :cascade }
      t.text :payload_ciphertext, null: false

      t.timestamps

      t.index :created_at
    end
  end
end
