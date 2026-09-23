# frozen_string_literal: true

# Flags an anonymous guest as a researcher test run, but only for a request that carries a valid
# test-link token minted for the intervention being filled.
#
# Fail-open by design: every rejection path returns `false` instead of raising, so an expired or
# tampered link degrades into an ordinary anonymous fill rather than blocking a real participant.
# The client is told which way it went (`meta.test_run`), because a refused marker is otherwise
# indistinguishable from a successful one.
#
# Marking is also what arms the deletion. A successful mark schedules
# `TestParticipants::PurgeTestParticipantsJob` one `RETENTION_WINDOW` out and records that same
# instant in `users.purge_scheduled_at` — see `persist!`. Everything this class refuses, refuses
# before that point, so a fill that is not marked is never scheduled for destruction either.
class V1::TestRuns::MarkGuest
  def self.call(user, intervention_id, token)
    new(user, intervention_id, token).call
  end

  def initialize(user, intervention_id, token)
    @user = user
    @intervention_id = intervention_id
    @token = token
  end

  def call
    return false unless markable?

    payload = V1::TestRuns::LinkToken.verify(token, intervention_id)
    return false if payload.blank?

    persist!(payload)
    true
  rescue StandardError => e
    # Covers both the marker write and the purge enqueue, so do not claim the marker failed: if
    # `perform_later` raised, the row is committed and only the fuse is missing — a stranded purge
    # the reconciler can pick up, not an unmarked guest.
    Rails.logger.warn("[V1::TestRuns::MarkGuest] test-run marking did not complete: #{e.class}")
    Sentry.capture_exception(e)
    false
  end

  private

  attr_reader :user, :intervention_id, :token

  # Raises on a failed write. `call` catches it, logs it and reports `false`, which leaves the fill
  # running as an ordinary participant — the same place every other rejection path lands.
  #
  # The deletion instant is resolved once and used for both `wait_until:` and `purge_scheduled_at`,
  # so `TestParticipants::StrandedPurgesQuery` — which compares the stamp against the clock — cannot
  # disagree with when the job actually fires.
  #
  # Enqueue follows the write: `update!` raises on failure, so a marker that was never persisted
  # never schedules a deletion. The converse (row written, enqueue then fails — Redis unreachable)
  # leaves a stranded purge. `purge_scheduled_at` makes it *findable*; recovering it needs somebody
  # to run `rake test_participants:reconcile_stranded_purges` by hand, because this repo has no
  # scheduler.
  def persist!(payload)
    purge_at = TestParticipants::PurgeTestParticipantsJob::RETENTION_WINDOW.from_now

    user.update!(
      test_run: true,
      test_run_intervention_id: intervention_id,
      test_run_marked_by_id: payload['minted_by_id'],
      purge_scheduled_at: purge_at
    )

    TestParticipants::PurgeTestParticipantsJob.set(wait_until: purge_at).perform_later(user.id)
  end

  # Only anonymous guests are markable — a registered participant must never be purgeable through
  # a link somebody forwarded to them. The age guard keeps the marker on the guest this fill just
  # created (or the one the invite landing page created moments earlier, within the token's own
  # lifetime) and shuts out a long-lived kiosk or shared-browser guest that already holds real
  # participant data.
  def markable?
    return false if token.blank? || intervention_id.blank?
    return false unless user.present? && user.role?('guest') && !user.test_run?

    user.created_at.present? && user.created_at > V1::TestRuns::LinkToken.ttl.ago
  end
end
