# frozen_string_literal: true

class Api::EpicOnFhir::EncountersSearch
  ENDPOINT = ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT')

  def self.call(patient_id)
    new(patient_id).call
  end

  def initialize(patient_id)
    @patient_id = patient_id
  end

  def call
    response = Faraday.get(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.params['_format'] = 'json'
      request.params['patient'] = patient_id
    end

    JSON.parse(response.body).deep_symbolize_keys
  end

  attr_reader :patient_id

  private

  def authentication
    @authentication ||= Api::EpicOnFhir::Authentication.call
  end
end
