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
    connection = Faraday.new ENDPOINT, ssl: Api::EpicOnFhir::SslOptions.call

    connection.get do |request|
      request.headers['Authorization'] = "#{authentication[:token_type]} #{authentication[:access_token]}"
      request.headers['Content-Type'] = 'application/fhir+json'
      request.headers['Accept'] = 'application/fhir+json'
      request.params['_format'] = 'json'
      request.params['identifier'] = identifier_param
    end
  end

  # Epic resolves a bare `identifier` value against every identifier type it
  # knows, which can match the wrong patient. Qualifying the search with
  # `system|value` removes that ambiguity - but we do not yet know which
  # identifier system the Aztec code's PtID belongs to (it is NOT necessarily
  # EPIC_ON_FHIR_SYSTEM, the MRN system used by $match). Until HFH confirms it,
  # EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM stays unset and we search unqualified,
  # exactly as before. Setting the env var is then the whole change.
  def identifier_param
    system = ENV.fetch('EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM', nil)

    system.presence ? "#{system}|#{patient_id}" : patient_id
  end

  def not_found_condition?(response)
    response[:total].zero?
  end
end
