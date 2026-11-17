# frozen_string_literal: true

class HenryFord::BarcodeParsingError < StandardError
  def initialize(msg = I18n.t('henry_ford.error.barcode.parsing_error'))
    super
  end
end
