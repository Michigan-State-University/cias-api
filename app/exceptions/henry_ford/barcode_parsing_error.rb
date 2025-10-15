# frozen_string_literal: true

class HenryFord::BarcodeParsingError < StandardError
  def initialize(msg = 'Unable to parse patient ID from barcode')
    super
  end
end
