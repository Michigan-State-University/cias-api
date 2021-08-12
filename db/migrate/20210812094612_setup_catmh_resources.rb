class SetupCatmhResources < ActiveRecord::Migration[6.0]
  def change
    Rake::Task['cat_mh:setup_resources'].invoke
  end
end
