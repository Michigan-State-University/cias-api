# frozen_string_literal: true

class AddDraftedByToHfhsPatientDetails < ActiveRecord::Migration[7.2]
  def change
    add_reference :hfhs_patient_details, :drafted_by, type: :uuid, null: true, index: true,
                                                      foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
