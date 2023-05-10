# frozen_string_literal: true

class Api::EpicOnFhir::Authentication
  ENDPOINT = ENV.fetch('EPIC_ON_FHIR_AUTHENTICATION_ENDPOINT')
  AUTHENTICATION_ALGORITHM = ENV.fetch('EPIC_ON_FHIR_AUTHENTICATION_ALGORITHM')
  CLIENT_ID = ENV.fetch('EPIC_ON_FHIR_CLIENT_ID')
  GRANT_TYPE = 'client_credentials'
  CLIENT_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

  def self.call
    new.call
  end

  def call
    response = Faraday.post(ENDPOINT) do |request|
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(params)
    end

    raise EpicOnFhir::AuthenticationError, I18n.t('epic_on_fhir.error.authentication') if response.status != 200

    JSON.parse(response.body).symbolize_keys
  end

  private

  def params
    {
      grant_type: GRANT_TYPE,
      client_assertion_type: CLIENT_ASSERTION_TYPE,
      client_assertion: client_assertion
    }
  end

  def client_assertion
    JWT.encode jwt_payload, key, AUTHENTICATION_ALGORITHM, jwt_header
  end

  def jwt_header
    {
      alg: AUTHENTICATION_ALGORITHM,
      typ: 'JWT'
    }
  end

  def jwt_payload
    {
      iss: CLIENT_ID,
      sub: CLIENT_ID,
      aud: ENDPOINT,
      jti: SecureRandom.uuid,
      exp: (Time.zone.now + 5.minutes).to_i
    }
  end

  def key
    OpenSSL::PKey::RSA.new ENV.fetch('EPIC_ON_FHIR_PRIVATE_KEY'), ENV.fetch('EPIC_ON_FHIR_PUBLIC_KEY')
  end
end
