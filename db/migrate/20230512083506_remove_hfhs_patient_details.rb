class RemoveHfhsPatientDetails < ActiveRecord::Migration[6.1]
  def change
    remove_foreign_key :users, column: 'hfhs_patient_detail_id'
    remove_column :users, :hfhs_patient_detail_id
    drop_table :hfhs_patient_details
  end
end
