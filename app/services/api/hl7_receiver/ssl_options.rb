# frozen_string_literal: true

# Builds the Faraday SSL options for outbound calls to HFHS's Cloverleaf HL7
# gateway (inforostst.hfhs.org). We do NOT pin (no PARTIAL_CHAIN) - pinning is what
# broke the integration in 2025. Instead we ADD the missing Entrust OV intermediate to
# the system store and let OpenSSL verify the chain normally. The added cert is ADDITIVE
# to the system trust store (set_default_paths), not exclusive - it does not restrict
# trust to HF's CA.
#
# Why the intermediate is required: the :7443 HL7 listener serves an INCOMPLETE chain
# (leaf only). HF confirmed they will not fix this, and OpenSSL (unlike Windows) does
# not AIA-fetch the missing issuer, so CIAS must supply it. The Sectigo R46 root comes
# from the system trust store (an up-to-date ca-certificates bundle - see the base-image
# bump); only add the root to HL7_RECEIVER_CA_CERT too as a fallback for a host that lacks R46.
#
# Verification is on unless HL7_RECEIVER_SSL_VERIFY is false, 0 or off (the env-only rollback). Blank stays on,
# so a missed setting fails the handshake loudly instead of sending PHI unverified.
#
#   * HL7_RECEIVER_SSL_VERIFY false/0/off    -> { verify: false } (unverified; rollback only).
#   * on + HL7_RECEIVER_CA_CERT set          -> verify against system roots + the added intermediate.
#   * on + HL7_RECEIVER_CA_CERT blank        -> system store only; verifies :443 but FAILS :7443
#                                               (incomplete chain) - so HL7_RECEIVER_CA_CERT must be set.
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

    # The CA cert setting carries the Entrust OV intermediate (added, not pinned), so NO
    # PARTIAL_CHAIN. scan() adds every PEM block found (so a root can be included too as a
    # fallback). Tolerate single-line env values with escaped "\n" (set via `dokku config:set`).
    normalized = ca_cert.gsub('\n', "\n")
    normalized.scan(PEM_CERTIFICATE).each do |pem|
      store.add_cert(OpenSSL::X509::Certificate.new(pem))
    end

    store
  end

  private_class_method :build_cert_store
end
