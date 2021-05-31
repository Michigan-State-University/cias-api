# frozen_string_literal: true

class AddTrendLineToChart < ActiveRecord::Migration[6.0]
  def change
    add_column :charts, :trend_line, :boolean, null: false, default: false
  end
end
