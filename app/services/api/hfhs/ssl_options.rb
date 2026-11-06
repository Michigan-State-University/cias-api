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
# bump); only add the root to HFHS_CA_CERT too as a fallback for a host that lacks R46.
#
# Verification is gated by HFHS_SSL_VERIFY (default OFF) so the code deploys inert and
# is switched on via env at a chosen window, with an env-only rollback (no redeploy).
#
#   * HFHS_SSL_VERIFY off (default) -> { verify: false } (unverified; inert until cutover).
#   * on + HFHS_CA_CERT set          -> verify against system roots + the added intermediate.
#   * on + HFHS_CA_CERT blank        -> system store only; verifies :443 but FAILS :7443
#                                       (incomplete chain) - so HFHS_CA_CERT must be set.
module Api::Hfhs::SslOptions
  PEM_CERTIFICATE = /-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m

  def self.call
    verify = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HFHS_SSL_VERIFY', false))
    return { verify: false } unless verify

    options = { verify: true }
    ca_cert = ENV.fetch('HFHS_CA_CERT', nil)
    options[:cert_store] = build_cert_store(ca_cert) if ca_cert.present?
    options
  end

  def self.build_cert_store(ca_cert)
    store = OpenSSL::X509::Store.new
    store.set_default_paths

    # HFHS_CA_CERT carries the Entrust OV intermediate (added, not pinned), so NO
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
