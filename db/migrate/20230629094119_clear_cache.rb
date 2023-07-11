class ClearCache < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['cache:clear'].invoke
  end
end
