class AddTrendLineToChart < ActiveRecord::Migration[6.0]
  def change
    add_column :charts, :trend_line, :boolean, default: false
  end
end
