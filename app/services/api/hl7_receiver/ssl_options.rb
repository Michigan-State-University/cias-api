# frozen_string_literal: true

# HL7_RECEIVER_CA_CERT is added to the system trust store, never pinned (pinning broke the integration in
# 2025). Blank HL7_RECEIVER_SSL_VERIFY verifies, so a missed setting can't send PHI unverified.
module Api::Hl7Receiver::SslOptions
  PEM_CERTIFICATE = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m

  def self.call
    return { verify: false } if ActiveModel::Type::Boolean.new.cast(Ehr::Settings.fetch('HL7_RECEIVER_SSL_VERIFY')) == false

    options = { verify: true }
    ca_cert = Ehr::Settings.fetch('HL7_RECEIVER_CA_CERT')
    options[:cert_store] = build_cert_store(ca_cert) if ca_cert.present?
    options
  end

  def self.build_cert_store(ca_cert)
    store = OpenSSL::X509::Store.new
    store.set_default_paths

    # A one-line value (dokku config:set) carries escaped "\n".
    normalized = ca_cert.gsub('\n', "\n")
    normalized.scan(PEM_CERTIFICATE).each do |pem|
      store.add_cert(OpenSSL::X509::Certificate.new(pem))
    end

    store
  end

  private_class_method :build_cert_store
end
