# frozen_string_literal: true

class V1::HenryFord::HandleBarCodeService
  include V1::HenryFord::EpicPatientResourceExtractor

  SYSTEM_IDENTIFIER = ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER')

  def self.call(user, params)
    new(user, params).call
  end

  def initialize(user, params)
    @user = user
    @params = params
  end

  attr_reader :user, :params

  def call
    patient_id = V1::HenryFord::ProcessBarcodeService.call(params)
    epic_response = Api::EpicOnFhir::PatientSearch.call(patient_id)
    # Several matches get the same 404 as a miss.
    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.patient.not_found') if epic_response[:total] != 1

    create_draft_patient_record(epic_response)
  end

  private

  # Always a new draft: a scanned label must never reach an existing record.
  def create_draft_patient_record(epic_response)
    draft = HfhsPatientDetail.create!(
      patient_id: hfhs_patient_id(epic_response),
      first_name: epic_first_name(epic_response),
      last_name: epic_last_name(epic_response),
      dob: epic_dob(epic_response),
      sex: epic_sex(epic_response),
      zip_code: epic_zip_code(epic_response),
      phone_type: epic_preferred_phone_type(epic_response),
      phone_number: epic_preferred_phone(epic_response)&.dig(:value),
      epic_id: epic_patient_id(epic_response),
      pending: true,
      drafted_by: user
    )
    schedule_draft_expiry
    draft
  end

  # The rake task isn't scheduled anywhere, so each draft enqueues its own expiry.
  def schedule_draft_expiry
    Hfhs::ClearAbandonedPatientDetailsJob.set(wait: Hfhs::ClearAbandonedPatientDetailsJob::RETENTION_PERIOD + 1.hour).perform_later
  end

  def hfhs_patient_id(epic_response)
    identifier = epic_response.dig(:entry, 0, :resource, :identifier).to_a.
                 find { |system_identifier| system_identifier.dig(:type, :text) == SYSTEM_IDENTIFIER }&.
                 dig(:value)

    raise HenryFord::PatientIdentifierMissingError if identifier.blank?

    identifier
  end
end
