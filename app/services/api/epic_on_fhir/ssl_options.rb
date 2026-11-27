# frozen_string_literal: true

# Verifies against the system trust store, never pinned. EPIC_ON_FHIR_SSL_VERIFY=false is the break-glass;
# if the chain fails because the host's ca-certificates is old, update it rather than leave this off.
module Api::EpicOnFhir::SslOptions
  def self.call
    { verify: ActiveModel::Type::Boolean.new.cast(ENV.fetch('EPIC_ON_FHIR_SSL_VERIFY', true)) }
  end
end
