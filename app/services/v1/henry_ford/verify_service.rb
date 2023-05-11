# frozen_string_literal: true

class V1::HenryFord::VerifyService
  def self.call(user, patient_params)
    new(user, patient_params).call
  end

  def initialize(user, patient_params)
    @user = user
    @patient_params = patient_params
  end

  attr_reader :user, :patient_params, :patient

  def call
    @patient = Api::EpicOnFhir::PatientVerification.call(first_name, last_name, parsed_dob, phone_number, zip_code)
    appointements = Api::EpicOnFhir::Appointments.call(patient_id)
    # todo: define way to get one needed visit_id from collection of appointments
  end

  private

  %w[first_name last_name sex dob zip_code phone_number].each do |param|
    define_method :"#{param}" do
      patient_params[param]
    end
  end

  def parsed_dob
    Date.parse(dob).strftime('%Y%m%d')
  end

  def patient_id
    patient.dig(:entry, 0, :resource, :id)
  end

  def verify_found_details(details)
    raise ActiveRecord::RecordNotFound, I18n.t('hfhs_patient_detail.not_found') if details.empty?
    raise ActiveRecord::RecordNotUnique, I18n.t('hfhs_patient_detail.not_unique') if details.size > 1
  end
end
