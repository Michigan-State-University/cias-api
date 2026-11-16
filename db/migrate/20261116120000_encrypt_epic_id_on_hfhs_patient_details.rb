# frozen_string_literal: true

# epic_id is HF's FHIR Patient id - a unique identifier that resolves to the full
# chart - so it is stored encrypted like the MRN beside it. Nothing queries by it,
# hence no blind index.
class EncryptEpicIdOnHfhsPatientDetails < ActiveRecord::Migration[7.2]
  def change
    change_table :hfhs_patient_details, bulk: true do |t|
      t.remove :epic_id, type: :string
      t.text :epic_id_ciphertext
    end
  end
end
