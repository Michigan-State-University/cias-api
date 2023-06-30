# frozen_string_literal: true

class Api::EpicOnFhir::PatientVerification < Api::EpicOnFhir::BaseService
  ENDPOINT = "#{ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')}$match?_format=json"

  def self.call(first_name, last_name, birth_date, phone_number, postal_code)
    new(first_name, last_name, birth_date, phone_number, postal_code).call
  end

  def initialize(first_name, last_name, birth_date, phone_number, postal_code)
    super()
    @first_name = first_name
    @last_name = last_name
    @birth_date = birth_date
    @phone_number = phone_number
    @postal_code = postal_code
  end

  def call
    require 'pry'; binding.pry
    response = Faraday.post(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/json'
      request.body = body
    end

    raise EpicOnFhir::UnexpectedError, I18n.t('epic_on_fhir.error.unexpected_error') if response.status != 200

    parsed_response = JSON.parse(response.body).deep_symbolize_keys

    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.not_found') if parsed_response[:total] != 1

    parsed_response
  end

  attr_reader :first_name, :last_name, :birth_date, :phone_number, :postal_code

  private

  def body
    {
      resourceType: 'Parameters',
      parameter: [
        {
          name: 'resource',
          resource: {
            resourceType: 'Patient',
            name: [
              {
                family: last_name,
                given: [first_name]
              }
            ],
            birthDate: birth_date,
            telecom: [
              {
                system: 'phone',
                value: phone_number,
                use: 'home'
              }
            ],
            address: [
              {
                postalCode: postal_code
              }
            ]
          }
        },
        {
          name: 'onlyCertainMatches',
          valueBoolean: 'true'
        }
      ]
    }.to_json
  end
end
