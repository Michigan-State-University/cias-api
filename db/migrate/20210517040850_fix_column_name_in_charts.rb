# frozen_string_literal: true

class FixColumnNameInCharts < ActiveRecord::Migration[6.0]
  def change
    rename_column :charts, :type, :chart_type
    change_column_default :charts, :chart_type, 'bar_chart'
  end
end
