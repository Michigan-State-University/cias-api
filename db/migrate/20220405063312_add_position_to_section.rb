class AddPositionToSection < ActiveRecord::Migration[6.1]
  def change
    add_column :report_template_sections, :position, :integer, default: 0, null: false
  end
end
