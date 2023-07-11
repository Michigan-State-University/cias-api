class AddInformationAboutPhoneToHfhsPatientDetail < ActiveRecord::Migration[6.1]
  def change
    add_column(:hfhs_patient_details, :phone_number_ciphertext, :string)
    add_column(:hfhs_patient_details, :phone_number_bidx, :string)
    add_column(:hfhs_patient_details, :phone_type_ciphertext, :string)
    add_column(:hfhs_patient_details, :phone_type_bidx, :string)
  end
end
