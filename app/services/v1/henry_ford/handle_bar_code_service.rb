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
    # Zero matches already raise EpicOnFhir::NotFound inside PatientSearch; several
    # matches answer the same way, so a caller cannot tell a miss from a hit on
    # more than one patient.
    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.patient.not_found') if epic_response[:total] != 1

    create_draft_patient_record(epic_response)
  end

  private

  # Every scan gets its own draft, owned by the user who scanned it. Holding a
  # label proves nothing yet, so an existing (possibly confirmed and matched)
  # record is never returned, shared or overwritten here.
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

  # Nothing schedules the rake task on Dokku or ECS, so each draft enqueues the
  # (idempotent) sweep that will expire it if nobody confirms it.
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
