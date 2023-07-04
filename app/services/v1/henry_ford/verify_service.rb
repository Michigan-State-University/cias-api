# frozen_string_literal: true

class V1::HenryFord::VerifyService
  SYSTEM_IDENTIFIER = ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER')

  def self.call(user, patient_params)
    new(user, patient_params).call
  end

  def initialize(user, patient_params)
    @user = user
    @patient_params = patient_params
  end

  attr_reader :user, :patient_params, :patient, :appointments

  def call
    @patient = Api::EpicOnFhir::PatientVerification.call(first_name, last_name, parsed_dob, phone_number, phone_type, zip_code)
    @appointments = Api::EpicOnFhir::Appointments.call(epic_patient_id)
    create_or_find_resource!
  end

  private

  %w[first_name last_name sex dob zip_code phone_number phone_type].each do |param|
    define_method :"#{param}" do
      patient_params[param]
    end
  end

  def parsed_dob
    Date.parse(dob).strftime('%Y-%m-%d')
  end

  def epic_patient_id
    patient.dig(:entry, 0, :resource, :id)
  end

  def hfhs_patient_id
    system_identifier_details&.dig(:value)
  end

  def system_identifier_details
    @system_identifier = patient.dig(:entry, 0, :resource, :identifier)
                      .find { |system_identifier| system_identifier.dig(:type, :text) == SYSTEM_IDENTIFIER }
  end

  def system_identifier
    system_identifier_details[:system]
  end

  def hfhs_visit_id
    # TODO: implement logic provided by Rajesh
    @appointments[:entry]
                 .find { |appointment| appointment.dig(:resource, :identifier, 0, :system) == system_id }
                 .dig(:resource, :identifier, :value)
  end

  def create_or_find_resource!
    result = HfhsPatientDetail.find_or_create_by!(
      patient_id: patient_id,
      first_name: first_name,
      last_name: last_name,
      dob: Date.parse(dob),
      gender: sex,
      zip: zip_code,
      phone: phone_number,
      phone_type: phone_type
    )
    result.update!(visit_id: hfhs_visit_id)
  end
end
