# frozen_string_literal: true

class EncryptEpicIdOnHfhsPatientDetails < ActiveRecord::Migration[7.2]
  def change
    change_table :hfhs_patient_details, bulk: true do |t|
      t.remove :epic_id, type: :string
      t.text :epic_id_ciphertext
    end
  end
end
