class AddPendingFlagToHfhsPatientDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :hfhs_patient_details, :pending, :boolean, default: false, null: false
  end
end
