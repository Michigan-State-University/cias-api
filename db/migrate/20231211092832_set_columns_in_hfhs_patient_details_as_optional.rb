class SetColumnsInHfhsPatientDetailsAsOptional < ActiveRecord::Migration[6.1]
  def change
    change_column :hfhs_patient_details, :first_name_ciphertext, :string, null: true
    change_column :hfhs_patient_details, :last_name_ciphertext, :string, null: true
    change_column :hfhs_patient_details, :dob_ciphertext, :string, null: true
    change_column :hfhs_patient_details, :sex_ciphertext, :string, null: true
    change_column :hfhs_patient_details, :zip_code_ciphertext, :string, null: true
  end
end
