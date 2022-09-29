class CreateHfhsPatientDetails < ActiveRecord::Migration[6.1]
  def change
    create_table :hfhs_patient_details, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :patient_id_ciphertext
      t.string :first_name_ciphertext
      t.string :last_name_ciphertext
      t.string :dob_ciphertext
      t.string :sex_ciphertext
      t.string :visit_id_ciphertext, default: ""
      t.string :zip_code_ciphertext, default: ""

      t.string :patient_id_bidx
      t.string :first_name_bidx
      t.string :last_name_bidx
      t.string :dob_bidx
      t.string :sex_bidx
      t.string :zip_code_bidx


      t.timestamps
    end

    add_reference :hfhs_patient_details, :user, foreign_key: true, type: :uuid, optional: true

    remove_column :users, :hfhs_patient_id
    remove_column :users, :dob
    remove_column :users, :sex
    remove_column :users, :hfhs_visit_id
    remove_column :users, :zip_code

    add_index :hfhs_patient_details, [:first_name_bidx, :last_name_bidx, :dob_bidx, :sex_bidx, :zip_code_bidx], name: :index_basic_hfhs_patient_details
    add_index :hfhs_patient_details, :patient_id_bidx
  end
end
