# frozen_string_literal: true

# Builds the Faraday SSL options for outbound calls to HFH's Epic-on-FHIR
# gateway (fhirdev.hfhs.org and its prod equivalent).
#
# The gateway serves a complete, publicly-valid chain
# (leaf *.hfhs.org -> Entrust OV TLS Issuing RSA CA 2 -> Sectigo Public Server
# Authentication Root R46), so verification needs no local cert material and no
# intermediate pinning - the system trust store validates the chain. We
# deliberately do NOT pin: pinning is fragile and was the source of the earlier
# integration break.
#
# EPIC_ON_FHIR_SSL_VERIFY (default true) is a break-glass env lever: set it to
# "false" to disable verification without a redeploy - e.g. if the deploy host's
# ca-certificates bundle predates the Sectigo R46 root. In that case the proper
# fix is to update ca-certificates on the host, not to leave verification off.
module Api::EpicOnFhir::SslOptions
  def self.call
    { verify: ActiveModel::Type::Boolean.new.cast(ENV.fetch('EPIC_ON_FHIR_SSL_VERIFY', true)) }
  end
end
