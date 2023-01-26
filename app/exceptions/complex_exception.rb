# frozen_string_literal: true

class ComplexException < StandardError
  def initialize(msg, additional_information)
    super(msg)
    @additional_information = additional_information
  end

  attr_reader :additional_information
end
