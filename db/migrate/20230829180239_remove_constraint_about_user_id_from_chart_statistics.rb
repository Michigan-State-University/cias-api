class RemoveConstraintAboutUserIdFromChartStatistics < ActiveRecord::Migration[6.1]
  def change
    change_column_null :chart_statistics, :user_id, true
  end
end
