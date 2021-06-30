# frozen_string_literal: true

class AddFilledAtToChartStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :chart_statistics, :filled_at, :datetime
  end
end
