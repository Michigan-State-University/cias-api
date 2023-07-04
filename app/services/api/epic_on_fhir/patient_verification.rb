# frozen_string_literal: true

class Api::EpicOnFhir::PatientVerification < Api::EpicOnFhir::BaseService
  ENDPOINT = "#{ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT')}$match"

  def self.call(first_name, last_name, birth_date, phone_number, phone_type, postal_code)
    new(first_name, last_name, birth_date, phone_number, phone_type, postal_code).call
  end

  def initialize(first_name, last_name, birth_date, phone_number, phone_type, postal_code)
    super()
    @first_name = first_name
    @last_name = last_name
    @birth_date = birth_date
    @phone_number = phone_number
    @phone_type = phone_type
    @postal_code = postal_code
  end

  attr_reader :first_name, :last_name, :birth_date, :phone_number, :phone_type, :postal_code

  private

  def request
    Faraday.post(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/json'
      request.params['_format'] = 'json'
      request.body = body
    end
  end

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
                use: phone_type
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

  def not_found_condition(response)
    response[:total] != 1
  end
end
