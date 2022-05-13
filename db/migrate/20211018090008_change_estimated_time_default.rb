class ChangeEstimatedTimeDefault < ActiveRecord::Migration[6.0]
  def change
    change_column_default(:sessions, :estimated_time, from: 0, to: nil)
  end
end
