# frozen_string_literal: true

class Api::EpicOnFhir::PatientVerification
  ENDPOINT = 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4/Patient/$match?_format=json'

  def self.call(first_name, last_name, birth_date, phone_number, postal_code)
    new(first_name, last_name, birth_date, phone_number, postal_code).call
  end

  def initialize(first_name, last_name, birth_date, phone_number, postal_code)
    @first_name = first_name
    @last_name = last_name
    @birth_date = birth_date
    @phone_number = phone_number
    @postal_code = postal_code
  end

  def call
    response = Faraday.post(ENDPOINT) do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/json'
      request.body = body
    end

    JSON.parse(response.body).deep_symbolize_keys
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

  # def date_of_birth_in_correct_format
  #   # YYYY-MM-DD -> https://www.hl7.org/fhir/datatypes.html#date
  #   birth_date.strftime('%Y-%m-%d')
  # end

  def authentication
    # todo: add error handling
    @authentication ||= Api::EpicOnFhir::Authentication.call
  end
end
