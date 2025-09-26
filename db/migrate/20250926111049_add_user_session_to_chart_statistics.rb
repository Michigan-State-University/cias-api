class AddUserSessionToChartStatistics < ActiveRecord::Migration[7.2]
  def change
    add_reference :chart_statistics, :user_session, foreign_key: true, type: :uuid
    # We are adding this columns, to make sure charts data is migrated properly
    # This columns should be removed after making sure that charts data is restored properly
    add_column :chart_statistics, :v2_record, :boolean, default: false
    add_column :chart_statistics, :regenerated, :boolean, default: false
  end
end
