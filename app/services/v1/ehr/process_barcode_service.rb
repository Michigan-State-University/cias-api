# frozen_string_literal: true

class V1::Ehr::ProcessBarcodeService
  # Fixed, whatever a site's settings allow: FHIR search syntax (`|`, `,`, `\`) would change the identifier search.
  FHIR_SAFE_PATIENT_ID = /\A[A-Za-z0-9.-]{1,64}\z/
  ID_CHARACTER = /[A-Za-z0-9.-]/
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
    barcode = verify_code_params[:barcode].to_s
    raise Ehr::BarcodeParsingError, I18n.t('ehr.error.barcode.patient_id_empty') if barcode.blank?
    raise Ehr::BarcodeParsingError if barcode.length > MAX_BARCODE_LENGTH

    match = pattern.match(barcode)
    raise Ehr::BarcodeParsingError unless match && whole_id?(barcode, match)

    patient_id = match[Ehr::Settings::BARCODE_PATIENT_ID_GROUP].to_s.strip
    raise Ehr::BarcodeParsingError, I18n.t('ehr.error.barcode.patient_id_empty') if patient_id.empty?
    raise Ehr::BarcodeParsingError unless patient_id.match?(FHIR_SAFE_PATIENT_ID)

    patient_id
  rescue Regexp::TimeoutError
    raise Ehr::BarcodeParsingError
  end

  private

  # A pattern without delimiters around the group could cut a longer ID down to another valid-looking one.
  def whole_id?(barcode, match)
    start, finish = match.offset(Ehr::Settings::BARCODE_PATIENT_ID_GROUP)
    return true if start.nil?

    [(barcode[start - 1] if start.positive?), barcode[finish]].compact.none? { |char| char.match?(ID_CHARACTER) }
  end
end
