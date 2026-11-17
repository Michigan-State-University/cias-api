# frozen_string_literal: true

class ComplexException < StandardError
  def initialize(msg, additional_information, status_code = :unprocessable_content)
    super(msg)
    @additional_information = additional_information
    @status_code = status_code
  end

  attr_reader :additional_information, :status_code
end
