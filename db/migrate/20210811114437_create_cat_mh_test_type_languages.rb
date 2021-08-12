class CreateCatMhTestTypeLanguages < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_test_type_languages do |t|
      t.integer :cat_mh_language_id
      t.integer :cat_mh_test_type_id
      t.belongs_to :cat_mh_languages, foreign_key: true
      t.belongs_to :cat_mh_test_types, foreign_key: true
      t.timestamps
    end
  end
end
