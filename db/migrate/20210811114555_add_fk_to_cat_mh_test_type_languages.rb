class AddFkToCatMhTestTypeLanguages < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :cat_mh_test_type_languages, :cat_mh_languages, column: :cat_mh_language_id
    add_foreign_key :cat_mh_test_type_languages, :cat_mh_test_types, column: :cat_mh_test_type_id
  end
end
