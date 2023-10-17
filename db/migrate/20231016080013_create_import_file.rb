class CreateImportFile < ActiveRecord::Migration[6.1]
  def change
    create_table :import_files, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|

      t.timestamps
    end
  end
end
