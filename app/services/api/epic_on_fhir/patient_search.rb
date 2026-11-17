# frozen_string_literal: true

class Api::EpicOnFhir::PatientSearch < Api::EpicOnFhir::BaseService
  ENDPOINT = ENV.fetch('EPIC_ON_FHIR_PATIENT_ENDPOINT').chomp('/').freeze

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
    identifier = identifier_param
    connection = Faraday.new ENDPOINT, ssl: Api::EpicOnFhir::SslOptions.call

    connection.get do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/fhir+json'
      request.headers['Accept'] = 'application/fhir+json'
      request.params['_format'] = 'json'
      request.params['identifier'] = identifier
    end
  end

  # A bare identifier also matches other ID types (e.g. the MRN), so never search unqualified.
  def identifier_param
    system = ENV.fetch('EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM', nil)
    raise EpicOnFhir::UnexpectedError, I18n.t('epic_on_fhir.error.unexpected_error') if system.blank?

    "#{system}|#{patient_id}"
  end

  def not_found_condition?(response)
    response[:total].zero?
  end
end
