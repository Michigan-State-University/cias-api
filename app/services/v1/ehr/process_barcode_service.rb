# frozen_string_literal: true

class V1::Ehr::ProcessBarcodeService
  # Fixed, whatever a site's settings allow: FHIR search syntax (`|`, `,`, `\`) would change the identifier search.
  FHIR_SAFE_PATIENT_ID = /\A[A-Za-z0-9.-]{1,64}\z/
  MAX_BARCODE_LENGTH = 1_000

  def self.call(verify_code_params)
    new(verify_code_params).call
  end

  def initialize(verify_code_params)
    @verify_code_params = verify_code_params
  end

  attr_reader :verify_code_params

  def call
    pattern = Ehr::Settings.barcode_patient_id_pattern
    format = Ehr::Settings.barcode_patient_id_format
    barcode = verify_code_params[:barcode].to_s
    raise Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.patient_id_empty') if barcode.blank?
    raise Ehr::BarcodeParsingError if barcode.length > MAX_BARCODE_LENGTH

    patient_id = patient_id_in(barcode, pattern)
    raise Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.patient_id_empty') if patient_id.empty?
    raise Ehr::BarcodeParsingError unless valid_patient_id?(patient_id, format)

    patient_id
  rescue Regexp::TimeoutError
    raise Ehr::BarcodeParsingError
  end

  private

  def patient_id_in(barcode, pattern)
    match = pattern.match(barcode)
    match ? match[Ehr::Settings::BARCODE_PATIENT_ID_GROUP].to_s.strip : ''
  end

  def valid_patient_id?(patient_id, format)
    patient_id.match?(FHIR_SAFE_PATIENT_ID) && (format.nil? || format.match?(patient_id))
  end
end
