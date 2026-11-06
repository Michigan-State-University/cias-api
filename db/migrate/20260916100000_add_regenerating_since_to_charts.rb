# frozen_string_literal: true

class AddRegeneratingSinceToCharts < ActiveRecord::Migration[7.2]
  def change
    add_column :charts, :regenerating_since, :datetime
  end
end
