# frozen_string_literal: true

class V1::HenryFord::HandleBarCodeService
  include V1::HenryFord::EpicPatientResourceExtractor

  SYSTEM_IDENTIFIER = ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER')

  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @params = params
  end

  attr_reader :params

  def call
    patient_id = V1::HenryFord::ProcessBarcodeService.call(params)
    epic_response = Api::EpicOnFhir::PatientSearch.call(patient_id)
    raise HenryFord::MultiplePatientsFoundError if epic_response[:total] != 1

    create_draft_patient_record(epic_response)
  end

  private

  def create_draft_patient_record(epic_response)
    resource = HfhsPatientDetail.find_or_initialize_by(
      patient_id: hfhs_patient_id(epic_response)
    )

    resource.assign_attributes(
      first_name: epic_first_name(epic_response),
      last_name: epic_last_name(epic_response),
      dob: epic_dob(epic_response),
      sex: epic_sex(epic_response),
      zip_code: epic_zip_code(epic_response),
      phone_type: epic_phone_type(epic_response),
      phone_number: epic_phone_number(epic_response),
      epic_id: epic_patient_id(epic_response),
      pending: true
    )

    resource.save!
    resource
  end

  def hfhs_patient_id(epic_response)
    epic_response.dig(:entry, 0, :resource, :identifier).
      find { |system_identifier| system_identifier.dig(:type, :text) == SYSTEM_IDENTIFIER }&.
      dig(:value)
  end
end
