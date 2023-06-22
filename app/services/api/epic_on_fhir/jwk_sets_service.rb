# frozen_string_literal: true

class Api::EpicOnFhir::JwkSetsService
  def self.call
    new.call
  end

  def call
    key = OpenSSL::PKey::RSA.new ENV.fetch('EPIC_ON_FHIR_PRIVATE_KEY'), ENV.fetch('EPIC_ON_FHIR_PUBLIC_KEY')
    jwk = JWT::JWK.new(key, optional_parameters)
    JWT::JWK::Set.new(jwk).export
  end

  private

  def optional_parameters
    { alg: ENV.fetch('EPIC_ON_FHIR_AUTHENTICATION_ALGORITHM'), kid: ENV.fetch('EPIC_ON_FHIR_KID') }
  end
end
