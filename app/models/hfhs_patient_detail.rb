# frozen_string_literal: true

class HfhsPatientDetail < ApplicationRecord
  has_paper_trail skip: %i[patient_id first_name last_name dob sex visit_id zip_code phone_number phone_type]

  audited except: %i[patient_id first_name last_name sex visit_id zip_code dob
                     phone_number phone_type provided_first_name provided_last_name
                     provided_sex provided_zip provided_phone_number provided_phone_type provided_dob
                     patient_id_ciphertext first_name_ciphertext last_name_ciphertext
                     sex_ciphertext visit_id_ciphertext zip_code_ciphertext dob_ciphertext
                     phone_number_ciphertext phone_type_ciphertext provided_first_name_ciphertext
                     provided_last_name_ciphertext provided_sex_ciphertext provided_zip_ciphertext
                     provided_phone_number_ciphertext provided_phone_type_ciphertext provided_dob_ciphertext]
  # ENCRYPTION
  has_encrypted :patient_id, :first_name, :last_name, :sex, :visit_id, :zip_code, :phone_number, :phone_type, :provided_first_name, :provided_last_name,
                :provided_sex, :provided_zip, :provided_phone_number, :provided_phone_type, :provided_dob
  has_encrypted :dob, type: :date
  blind_index :patient_id, :first_name, :last_name, :dob, :sex, :zip_code, :phone_number, :phone_type, :provided_first_name, :provided_last_name,
              :provided_sex, :provided_zip, :provided_phone_number, :provided_phone_type, :provided_dob

  has_many :users, dependent: :nullify

  validates :patient_id, presence: true

  enum :phone_type, { home: 'home', mobile: 'mobile', work: 'work' }
end
