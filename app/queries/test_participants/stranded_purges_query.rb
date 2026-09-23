# frozen_string_literal: true

# Marked test participants whose purge fell due and did not happen — the recovery path for work
# item 2.11.
#
# A scheduled purge lives for a full 24 hours in Sidekiq's scheduled ZSET, which is Redis state. If
# Redis is flushed, evicted or replaced, every pending purge vanishes with no error anywhere, and
# since decision D6 dropped the manual purge there is no route to clean up behind it. Persisting
# `purge_scheduled_at` at marking time makes those records *findable*; this query is how they are
# found, and `V1::Intervention::TestParticipants::ReconcileStrandedPurges` is how they are recovered.
#
# **`test_run_intervention_id` is a required part of the predicate, not decoration.** `test_run` is
# a user-level flag while the link that sets it is minted per intervention, and one anonymous guest
# identity legitimately spans several "anyone with the link" interventions belonging to different
# researchers. A candidate carrying no intervention cannot be scoped to one, so it must never be
# handed to a destructive job: `PurgeService` would refuse it as `:unscoped_marker` anyway, but the
# guard belongs here too, where the candidate set is chosen.
#
# Note what is *not* in the predicate: this does not try to distinguish "the job was lost" from
# "the job is mid-flight" — a purge that is merely running late is re-enqueued too. That is
# deliberate and safe, because `PurgeService` takes a row lock and is idempotent, so the redundant
# run is a `:already_purged` / `:not_marked` no-op.
#
# The `test_run = true` leg is covered by the partial index `index_users_on_test_run`.
class TestParticipants::StrandedPurgesQuery
  def self.call(now = Time.current)
    new(now).call
  end

  def initialize(now = Time.current)
    @now = now
  end

  # Beginless range — compiles to `purge_scheduled_at < $1`, and NULLs are excluded by SQL's
  # three-valued logic, so a user who was never scheduled is not a candidate.
  def call
    User.where(test_run: true)
        .where.not(test_run_intervention_id: nil)
        .where(purge_scheduled_at: ...now)
  end

  private

  attr_reader :now
end
