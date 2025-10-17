class AddEpicIdToHfhsPatientDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :hfhs_patient_details, :epic_id, :string, null: true
  end
end
