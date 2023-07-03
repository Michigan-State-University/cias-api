# frozen_string_literal: true

class Api::EpicOnFhir::Appointments < Api::EpicOnFhir::BaseService
  ENDPOINT = "#{ENV.fetch('EPIC_ON_FHIR_APPOINTMENTS_ENDPOINT')}?_format=json"

  def self.call(patient_id)
    new(patient_id).call
  end

  def initialize(patient_id)
    super()
    @patient_id = patient_id
  end

  def call
    response = Faraday.post(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/json'
      request.params['_format'] = 'json'
      request.params['patient'] = patient_id
    end

    check_status(response)

    parsed_response = JSON.parse(response.body).deep_symbolize_keys

    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.appointments.not_found') if parsed_response[:total].zero?

    parsed_response
  end

  attr_reader :patient_id
end
