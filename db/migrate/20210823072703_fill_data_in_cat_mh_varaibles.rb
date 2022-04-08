class FillDataInCatMhVaraibles < ActiveRecord::Migration[6.0]
  def change
    Rake::Task['cat_mh:fill_cat_test_properties'].invoke
  end
end
