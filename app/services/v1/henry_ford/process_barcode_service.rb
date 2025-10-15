# frozen_string_literal: true

require_relative '../../../exceptions/henry_ford/barcode_parsing_error'

class V1::HenryFord::ProcessBarcodeService
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

    patient_id = barcode[%r{<PtID>(.*?)</PtID>}, 1]

    raise HenryFord::BarcodeParsingError, I18n.t('henry_ford.error.barcode.patient_id_empty') if patient_id.blank?

    patient_id
  end
end
