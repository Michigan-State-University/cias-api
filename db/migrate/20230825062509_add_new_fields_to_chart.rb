class AddNewFieldsToChart < ActiveRecord::Migration[6.1]
  def change
    add_column(:charts, :interval_type, :string, default: 'monthly')
    add_column(:charts, :date_range_start, :datetime)
    add_column(:charts, :date_range_end, :datetime)
  end
end
