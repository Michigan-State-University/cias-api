class AddPositionToChart < ActiveRecord::Migration[6.0]
  def change
    add_column :charts, :position, :integer, default: 1, null: false
  end
end
