class CreateImportedFile < ActiveRecord::Migration[6.1]
  def change
    create_table :imported_files, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|

      t.timestamps
    end
  end
end
