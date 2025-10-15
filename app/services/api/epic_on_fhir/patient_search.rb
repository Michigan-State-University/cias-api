# frozen_string_literal: true

class Api::EpicOnFhir::PatientSearch < Api::EpicOnFhir::BaseService
  ENDPOINT = ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')[0..-2].freeze

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
    Faraday.get(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/fhir+json'
      request.params['_format'] = 'json'
      request.params['identifier'] = patient_id
    end
  end

  def not_found_condition?(response)
    response[:total].zero?
  end
end
