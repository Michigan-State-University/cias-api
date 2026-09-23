# frozen_string_literal: true

class V1::TestRuns::LinkToken
  PURPOSE = 'cias/test_link'
  DEFAULT_TTL_MINUTES = 15

  Minted = Struct.new(:token, :expires_at, :nonce, keyword_init: true)

  Inspection = Struct.new(:status, :payload, keyword_init: true) do
    def valid?
      status == :valid
    end

    def intervention_id
      payload&.fetch('intervention_id', nil)
    end
  end

  class << self
    def mint(intervention_id, minted_by_id)
      nonce = SecureRandom.uuid
      expires_at = Time.current + ttl

      token = verifier.generate(
        {
          'intervention_id' => intervention_id.to_s,
          'minted_by_id' => minted_by_id.presence&.to_s,
          'nonce' => nonce
        },
        purpose: PURPOSE,
        expires_at: expires_at
      )

      Minted.new(token: token, expires_at: expires_at, nonce: nonce)
    end

    def verify(token, intervention_id)
      return nil if token.blank? || intervention_id.blank?

      inspection = inspect_token(token)

      return nil unless inspection.valid?
      return nil unless inspection.intervention_id.to_s == intervention_id.to_s

      inspection.payload
    end

    # Not `inspect`: that is `Module#inspect` on a class object, and overriding it corrupts every backtrace and log line.
    def inspect_token(token)
      return Inspection.new(status: :invalid) if token.blank?

      payload = verifier.verified(token.to_s, purpose: PURPOSE)

      return Inspection.new(status: :valid, payload: payload) if usable_payload?(payload)
      return Inspection.new(status: :invalid) unless payload.nil?

      Inspection.new(status: verifier.valid_message?(token.to_s) ? :expired : :invalid)
    rescue StandardError => e
      Rails.logger.warn("[V1::TestRuns::LinkToken] rejected test-link token: #{e.class}")
      Inspection.new(status: :invalid)
    end

    # A blank or non-numeric env value would coerce to `0.minutes`, minting tokens that are already expired.
    def ttl
      minutes = ENV.fetch('TEST_LINK_TOKEN_TTL_MINUTES', DEFAULT_TTL_MINUTES).to_i

      (minutes.positive? ? minutes : DEFAULT_TTL_MINUTES).minutes
    end

    private

    def usable_payload?(payload)
      payload.is_a?(Hash) && payload['nonce'].present? && payload['intervention_id'].present?
    end

    # Explicit rather than `Rails.application.message_verifier` only so the token can be `url_safe` in an invite URL.
    def verifier
      ActiveSupport::MessageVerifier.new(
        Rails.application.key_generator.generate_key(PURPOSE, 32),
        digest: 'SHA256',
        serializer: JSON,
        url_safe: true
      )
    end
  end
end
