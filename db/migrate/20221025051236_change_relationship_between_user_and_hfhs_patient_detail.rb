class ChangeRelationshipBetweenUserAndHfhsPatientDetail < ActiveRecord::Migration[6.1]
  def change
    remove_column :hfhs_patient_details, :user_id
    add_reference :users, :hfhs_patient_detail, foreign_key: true, type: :uuid, optional: true
  end
end
