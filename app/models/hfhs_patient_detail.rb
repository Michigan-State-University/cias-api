# frozen_string_literal: true

class HfhsPatientDetail < ApplicationRecord
  has_paper_trail skip: %i[patient_id first_name last_name dob sex visit_id zip_code phone_number phone_type]

  # ENCRYPTION
  encrypts :patient_id, :first_name, :last_name, :sex, :visit_id, :zip_code, :phone_number, :phone_type, :provided_first_name, :provided_last_name,
           :provided_sex, :provided_zip, :provided_phone_number, :provided_phone_type, :provided_dob
  encrypts :dob, type: :date
  blind_index :patient_id, :first_name, :last_name, :dob, :sex, :zip_code, :phone_number, :phone_type, :provided_first_name, :provided_last_name,
              :provided_sex, :provided_zip, :provided_phone_number, :provided_phone_type, :provided_dob

  alias_attribute :zip, :zip_code
  alias_attribute :gender, :sex
  alias_attribute :provided_gender, :provided_sex

  has_many :users, dependent: :nullify

  validates :patient_id, presence: true

  enum phone_type: { home: 'home', mobile: 'mobile', work: 'work' }
end
