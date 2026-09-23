# frozen_string_literal: true

# Mints and verifies the credential that lets an anonymous ("Anyone With The Link") fill be marked
# as a researcher test run.
#
# The token is a time-boxed capability, not a ticket to be spent: inside its TTL it marks every
# fill that presents it, and nothing counts them. A per-token ceiling was tried (decision D8) and
# removed — capping the marks only moves the silent-failure cliff, and the fill on the far side of
# it is recorded as a permanent, un-purgeable real participant, which is the exact pollution this
# feature exists to prevent. Three bounds remain, and they are the ones that matter: the token
# names a single intervention (checked in `verify`), it expires (`ttl`), and minting one requires
# `authorize! :update` on that intervention.
#
# The token is an `ActiveSupport::MessageVerifier` message keyed off `secret_key_base` — the same
# construction `Rails.application.message_verifier` uses, spelled out here only so the output can be
# URL-safe. It is signed but not secret: it carries the intervention it was minted for, the
# researcher who minted it, a nonce, and an expiry stamp, all of which are tamper-evident.
# A client-supplied `test_run` boolean is never trusted anywhere — the marker can only be set by
# presenting a token this class minted.
class V1::TestRuns::LinkToken
  PURPOSE = 'cias/test_link'
  DEFAULT_TTL_MINUTES = 15

  Minted = Struct.new(:token, :expires_at, :nonce, keyword_init: true)

  # What `inspect_token` reports. `status` is one of `:valid`, `:expired` or `:invalid`; `payload` is
  # populated for `:valid` only, because an unusable token's contents are not to be believed.
  Inspection = Struct.new(:status, :payload, keyword_init: true) do
    def valid?
      status == :valid
    end

    def intervention_id
      payload&.fetch('intervention_id', nil)
    end
  end

  class << self
    # `minted_by_id` is the researcher accountable for the marker. It is carried in the signed
    # payload and persisted on the marked guest, because the marker eventually authorises the
    # destruction of study data and the anonymous fill request has no actor of its own to audit.
    #
    # The `nonce` no longer gates anything — it is the mint response's `id`, and it keeps two
    # tokens minted for the same intervention in the same second distinguishable in a log.
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

    # Returns the decoded payload of a token that is well-formed, correctly signed, unexpired and
    # minted for `intervention_id`; `nil` for anything else. Never raises — an unusable token has
    # to degrade the fill to an ordinary non-test fill, not break it for a real participant.
    def verify(token, intervention_id)
      return nil if token.blank? || intervention_id.blank?

      inspection = inspect_token(token)

      return nil unless inspection.valid?
      return nil unless inspection.intervention_id.to_s == intervention_id.to_s

      inspection.payload
    end

    # Says *why* a token is unusable, which `verify` deliberately does not: `verify` answers one
    # yes/no for the fill path and collapses every rejection into `nil`. The landing-time check
    # needs the distinction, because "your link expired, copy a fresh one" and "this is not a test
    # link" are different things to put in front of a researcher.
    #
    # Read-only and side-effect free: nothing is spent, counted or written, and a token survives any
    # number of inspections — the same property `verify` has. It runs the signature, purpose and
    # expiry checks and stops there; binding the token to an intervention stays in `verify`, because
    # the token names its own intervention and a caller who only holds the token has no independent
    # intervention to check it against.
    #
    # Not called `inspect`: that is `Module#inspect` on a class object, and overriding it would
    # corrupt every backtrace, log line and debugger session that prints this class.
    #
    # `:expired` is reached by elimination — the digest is one of ours, yet `verified` still refused
    # the message, and expiry is the only metadata check left that a token this class minted can
    # fail. Forging a message under our own derived key with some other purpose would land here too,
    # but that needs `secret_key_base`, and a holder of that can mint genuinely valid tokens.
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

    # A blank or non-numeric `TEST_LINK_TOKEN_TTL_MINUTES` would otherwise coerce to `0.minutes`,
    # which mints tokens that are already expired — the feature would fail open and silently.
    def ttl
      minutes = ENV.fetch('TEST_LINK_TOKEN_TTL_MINUTES', DEFAULT_TTL_MINUTES).to_i

      (minutes.positive? ? minutes : DEFAULT_TTL_MINUTES).minutes
    end

    private

    # A signed, fresh, correctly-purposed message can still be something other than one of our
    # tokens — an empty hash, a string, a hash minted by an older shape of `mint`. Those are not
    # "expired", they are not tokens at all.
    def usable_payload?(payload)
      payload.is_a?(Hash) && payload['nonce'].present? && payload['intervention_id'].present?
    end

    # Same construction `Rails.application.message_verifier` uses — a key derived from
    # `secret_key_base` — but built explicitly so the token can be `url_safe`: it is appended to an
    # invite URL by the researcher-facing "copy test link" flow, and a raw Base64 `+`/`/`/`=` there
    # is a well-known source of double-encoding bugs.
    # `Rails.application.key_generator` is a CachingKeyGenerator, so the expensive PBKDF2 derivation
    # happens once per process however often this is called.
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
