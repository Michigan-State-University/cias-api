# frozen_string_literal: true

# Re-enqueues test-participant purges that were scheduled, fell due, and never ran — work item
# 2.11, driven by `rake test_participants:reconcile_stranded_purges`.
#
# The failure it exists for: a scheduled purge sits in Sidekiq's scheduled ZSET for 24 hours, and
# that is Redis state. Flush, evict or replace Redis and every pending purge disappears silently —
# no exception, no dead set, no retry. With `purge_scheduled_at` persisted on the user, the
# stranded records stay findable; this service makes them recoverable.
#
# **Safe to run twice, and safe to run while purges are in flight.** It only enqueues; every
# decision about what may be destroyed is re-made inside `PurgeService`, under a row lock, against
# the marker as it stands at execution time. A user purged between two runs is gone from the
# candidate set; a user whose purge completed but whose shell survived had the marker released by
# the service, so they are gone from it too; a duplicate job for a live candidate is an
# `:already_purged` / `:not_marked` no-op.
#
# **It does not write `purge_scheduled_at`.** Re-stamping the column would look tidy but it would
# hide the evidence: the timestamp is the only record that a purge was owed and missed, and the
# reconciler's own idempotency does not depend on clearing it.
#
# This codebase has no periodic scheduler — no `sidekiq-cron`, no `whenever`, no `:schedule` block
# in `config/sidekiq.yml`, and Sidekiq OSS has no built-in cron — so this runs manually, or from
# whatever deploy-side scheduling exists. Wiring it to a real scheduler is a separate decision.
class V1::Intervention::TestParticipants::ReconcileStrandedPurges
  BATCH_SIZE = 500

  # `in_batches` bounds memory, not the total: without a ceiling this loop enqueues one irreversible
  # deletion per candidate, however many there are. The realistic way that set becomes large is a
  # backfill — `User.where(test_run: true).update_all(purge_scheduled_at: Time.current)`, written to
  # "catch up" markers created before item 2.5 was wired — which makes every marked guest
  # immediately due, including any genuine participant mis-marked under SEC-R2-1. Refuse an
  # unexpectedly large run and make the operator raise the ceiling deliberately.
  #
  # The ceiling is checked against the count, so it is not race-proof against rows becoming due
  # between the count and the iteration; it is a guard against an operator running this after a
  # bulk stamp, which is the failure it exists for, not a hard concurrency bound.
  MAX_PURGES_PER_RUN = 100

  Result = Struct.new(:found, :enqueued, :dry_run, :refused, :max_purges, :candidate_ids, keyword_init: true) do
    def dry_run?
      dry_run
    end

    def refused?
      refused
    end
  end

  def self.call(dry_run: false, now: Time.current, max_purges: MAX_PURGES_PER_RUN)
    new(dry_run: dry_run, now: now, max_purges: max_purges).call
  end

  def initialize(dry_run: false, now: Time.current, max_purges: MAX_PURGES_PER_RUN)
    @dry_run = dry_run
    @now = now
    @max_purges = max_purges
  end

  def call
    candidates = TestParticipants::StrandedPurgesQuery.call(now)
    found = candidates.count
    refused = refuse?(found)
    dispatch = !dry_run && !refused
    ids = collect_ids(candidates, dispatch: dispatch)

    log(found, ids, refused)

    Result.new(found: found, enqueued: dispatch ? ids.size : 0, dry_run: dry_run, refused: refused,
               max_purges: max_purges, candidate_ids: ids)
  end

  private

  attr_reader :dry_run, :now, :max_purges

  # A dry run is never refused — it destroys nothing, and truncating the preview would hide exactly
  # the scale the operator needs to see. `max_purges: nil` disables the ceiling for a caller that
  # means it; the rake task never passes nil.
  def refuse?(found)
    !dry_run && max_purges.present? && found > max_purges
  end

  # `pluck` rather than instantiating: the job only needs an id, and a `User` carries encrypted
  # attributes there is no reason to decrypt here. Batched so a large backlog — the case this
  # exists for — does not load every candidate at once.
  def collect_ids(candidates, dispatch:)
    ids = []

    candidates.in_batches(of: BATCH_SIZE) do |batch|
      batch_ids = batch.pluck(:id)
      batch_ids.each { |user_id| TestParticipants::PurgeTestParticipantsJob.perform_later(user_id) } if dispatch
      ids.concat(batch_ids)
    end

    ids
  end

  # `warn`, not `info`: production runs at `config.log_level = :warn`
  # (`config/environments/production.rb:64`), so an INFO line is written nowhere an operator can
  # read it.
  #
  # PHI-free by construction: three integers, two booleans and bare user UUIDs — nothing decrypted,
  # the same shape `Log::UserRequest` already persists. The ids matter because a run whose enqueued
  # jobs are themselves lost leaves no other trace of whom it targeted: `PurgeService`'s own line is
  # written only by purges that actually executed.
  def log(found, ids, refused)
    Rails.logger.warn(
      "[TestParticipants::ReconcileStrandedPurges] found=#{found} enqueued=#{refused || dry_run ? 0 : ids.size} " \
      "dry_run=#{dry_run} refused=#{refused} max_purges=#{max_purges} user_ids=#{ids.join(',')}"
    )
  end
end
