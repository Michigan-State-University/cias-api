# frozen_string_literal: true

class RemoveV2RecordFieldFromChartStatistics < ActiveRecord::Migration[7.2]
  def change
    remove_column :chart_statistics, :v2_record
  end
end
