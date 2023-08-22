class AddHfhFieldsToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :hfhs_patient_id, :string
    add_column :users, :dob, :datetime #19610824
    add_column :users, :sex, :string
    add_column :users, :hfhs_visit_id, :string, default: ""
    add_column :users, :zip_code, :string, default: ""
  end
end
