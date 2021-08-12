class CreateCatMhLanguages < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_languages do |t|
      t.integer :language_id
      t.string :name

      t.timestamps
    end
  end
end
