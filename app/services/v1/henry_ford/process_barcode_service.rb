# frozen_string_literal: true

class V1::HenryFord::ProcessBarcodeService
  # The PtID is the Epic internal patient ID (EPT .1): letters and digits,
  # space-padded to 10 characters on the label. Anything else - FHIR search
  # syntax such as `|`, `,` or `\` included - is rejected, so the caller cannot
  # choose the identifier system or OR several identifiers into one search.
  PATIENT_ID_FORMAT = /\A[A-Za-z0-9]{1,10}\z/

  def self.call(verify_code_params)
    new(verify_code_params).call
  end

  def initialize(verify_code_params)
    @verify_code_params = verify_code_params
  end

  attr_reader :verify_code_params

  def call
    barcode = verify_code_params[:barcode]
    raise HenryFord::BarcodeParsingError, I18n.t('henry_ford.error.barcode.patient_id_empty') if barcode.blank?

    patient_id = barcode.to_s[%r{<PtID>(.*?)</PtID>}, 1].to_s.strip

    raise HenryFord::BarcodeParsingError, I18n.t('henry_ford.error.barcode.patient_id_empty') if patient_id.empty?
    raise HenryFord::BarcodeParsingError unless patient_id.match?(PATIENT_ID_FORMAT)

    patient_id
  end
end
