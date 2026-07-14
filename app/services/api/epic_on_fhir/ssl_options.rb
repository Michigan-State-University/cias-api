# frozen_string_literal: true

# Builds the Faraday SSL options for outbound calls to HFH's Epic-on-FHIR
# gateway. TLS verification is always ON. When EPIC_ON_FHIR_CA_CERT is set, its
# PEM contents (e.g. HFH's issuing intermediate CA) are added to a trust store
# alongside the system roots, so verification still succeeds if the gateway
# serves an incomplete certificate chain.
module Api::EpicOnFhir::SslOptions
  PEM_CERTIFICATE = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m

  def self.call
    options = { verify: true }

    ca_cert = ENV['EPIC_ON_FHIR_CA_CERT']
    options[:cert_store] = build_cert_store(ca_cert) if ca_cert.present?

    options
  end

  def self.build_cert_store(ca_cert)
    store = OpenSSL::X509::Store.new
    store.set_default_paths

    # Tolerate single-line env values where newlines are escaped as "\n"
    # (e.g. set via `dokku config:set`), as well as real multi-line PEM.
    normalized = ca_cert.gsub('\n', "\n")

    normalized.scan(PEM_CERTIFICATE).each do |pem|
      store.add_cert(OpenSSL::X509::Certificate.new(pem))
    end

    store
  end

  private_class_method :build_cert_store

end
