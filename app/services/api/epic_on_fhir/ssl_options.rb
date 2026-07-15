# frozen_string_literal: true

# Builds the Faraday SSL options for outbound calls to HFH's Epic-on-FHIR
# gateway. TLS verification is always ON.
#
# HFH serves an incomplete chain (leaf + Entrust intermediate), so we add the
# missing trust anchor ourselves. Which anchor is controlled by
# EPIC_ON_FHIR_CA_PIN_INTERMEDIATE:
#
#   * true (default) - pin the Entrust intermediate (EPIC_ON_FHIR_CA_INTERMEDIATE_CERT).
#     Tighter trust: only certs issued under that one intermediate are accepted.
#     Requires PARTIAL_CHAIN so a non-self-signed cert can terminate the chain.
#     Note: the intermediate expires 2027-12-10, so it must be refreshed on HFH's
#     rotation.
#   * false - anchor on the long-lived Sectigo root (EPIC_ON_FHIR_CA_ROOT_CERT,
#     expires 2046). Survives HFH rotating their leaf/intermediate as long as they
#     stay under that root.
module Api::EpicOnFhir::SslOptions
  PEM_CERTIFICATE = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m

  def self.call
    options = { verify: true }

    pin_intermediate = ActiveModel::Type::Boolean.new.cast(ENV.fetch('EPIC_ON_FHIR_CA_PIN_INTERMEDIATE', true))
    ca_cert = pin_intermediate ? ENV.fetch('EPIC_ON_FHIR_CA_INTERMEDIATE_CERT', nil) : ENV.fetch('EPIC_ON_FHIR_CA_ROOT_CERT', nil)

    options[:cert_store] = build_cert_store(ca_cert, pin_intermediate) if ca_cert.present?

    options
  end

  def self.build_cert_store(ca_cert, pin_intermediate)
    store = OpenSSL::X509::Store.new
    store.set_default_paths

    # A pinned intermediate is not a self-signed root, so allow any cert in the
    # store to terminate the chain.
    store.flags = OpenSSL::X509::V_FLAG_PARTIAL_CHAIN if pin_intermediate

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
