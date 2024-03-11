class AddProvidedValuesToHfhsPatientDetails < ActiveRecord::Migration[6.1]
  def change
    change_table(:hfhs_patient_details, bulk: true) do |t|
      t.string :provided_first_name_ciphertext
      t.string :provided_last_name_ciphertext
      t.string :provided_dob_ciphertext
      t.string :provided_sex_ciphertext
      t.string :provided_zip_ciphertext
      t.string :provided_phone_type_ciphertext
      t.string :provided_phone_number_ciphertext

      t.string :provided_first_name_bidx
      t.string :provided_last_name_bidx
      t.string :provided_dob_bidx
      t.string :provided_sex_bidx
      t.string :provided_zip_bidx
      t.string :provided_phone_type_bidx
      t.string :provided_phone_number_bidx
    end
  end
end
