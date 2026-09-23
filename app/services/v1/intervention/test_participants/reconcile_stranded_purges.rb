# frozen_string_literal: true

# Re-enqueues purges that fell due and never ran — a scheduled job lives in Redis, so flushing it loses every pending purge silently.
class V1::Intervention::TestParticipants::ReconcileStrandedPurges
  BATCH_SIZE = 500

  # A ceiling, because every candidate is an irreversible deletion. Guards against an operator running this after a bulk `purge_scheduled_at` stamp.
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

  def refuse?(found)
    !dry_run && max_purges.present? && found > max_purges
  end

  def collect_ids(candidates, dispatch:)
    ids = []

    candidates.in_batches(of: BATCH_SIZE) do |batch|
      batch_ids = batch.pluck(:id)
      batch_ids.each { |user_id| TestParticipants::PurgeTestParticipantsJob.perform_later(user_id) } if dispatch
      ids.concat(batch_ids)
    end

    ids
  end

  # `warn` because production runs at `log_level = :warn`. The ids matter: if these jobs are lost too, nothing else records whom the run targeted.
  def log(found, ids, refused)
    Rails.logger.warn(
      "[TestParticipants::ReconcileStrandedPurges] found=#{found} enqueued=#{refused || dry_run ? 0 : ids.size} " \
      "dry_run=#{dry_run} refused=#{refused} max_purges=#{max_purges} user_ids=#{ids.join(',')}"
    )
  end
end
