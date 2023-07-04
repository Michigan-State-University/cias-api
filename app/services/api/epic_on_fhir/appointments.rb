# frozen_string_literal: true

class Api::EpicOnFhir::Appointments < Api::EpicOnFhir::BaseService
  ENDPOINT = ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT')

  def self.call(patient_id)
    new(patient_id).call
  end

  def initialize(patient_id)
    super()
    @patient_id = patient_id
  end

  attr_reader :patient_id

  private

  def request
    Faraday.post(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/json'
      request.params['_format'] = 'json'
      request.params['patient'] = patient_id
    end
  end

  def not_found_condition(response)
    response[:total].zero?
  end
end
