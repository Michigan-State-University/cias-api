class SeedsTimeRange < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:seeds_time_ranges'].invoke
  end
end
