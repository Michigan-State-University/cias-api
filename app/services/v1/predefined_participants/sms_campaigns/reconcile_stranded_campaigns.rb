# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::ReconcileStrandedCampaigns
  BATCH_SIZE = 500
  MAX_CAMPAIGNS_PER_RUN = 100

  Result = Struct.new(:found, :enqueued, :dry_run, :refused, :max_campaigns, :candidate_ids, keyword_init: true) do
    def dry_run?
      dry_run
    end

    def refused?
      refused
    end
  end

  def self.call(dry_run: false, now: Time.current, max_campaigns: MAX_CAMPAIGNS_PER_RUN)
    new(dry_run: dry_run, now: now, max_campaigns: max_campaigns).call
  end

  def initialize(dry_run: false, now: Time.current, max_campaigns: MAX_CAMPAIGNS_PER_RUN)
    @dry_run = dry_run
    @now = now
    @max_campaigns = max_campaigns
  end

  def call
    candidates = ::PredefinedParticipants::StrandedCampaignsQuery.call(now)
    found = candidates.count
    refused = refuse?(found)
    dispatch = !dry_run && !refused
    ids = collect_ids(candidates, dispatch: dispatch)

    log(found, ids, refused)

    Result.new(found: found, enqueued: dispatch ? ids.size : 0, dry_run: dry_run, refused: refused,
               max_campaigns: max_campaigns, candidate_ids: ids)
  end

  private

  attr_reader :dry_run, :now, :max_campaigns

  def refuse?(found)
    !dry_run && max_campaigns.present? && found > max_campaigns
  end

  def collect_ids(candidates, dispatch:)
    ids = []

    candidates.in_batches(of: BATCH_SIZE) do |batch|
      batch.pluck(:id, :scheduled_at).each do |campaign_id, scheduled_at|
        ::PredefinedParticipants::SendSmsCampaignJob.set(wait_until: scheduled_at).perform_later(campaign_id) if dispatch
        ids << campaign_id
      end
    end

    ids
  end

  def log(found, ids, refused)
    Rails.logger.warn(
      "[#{self.class.name}] found=#{found} enqueued=#{refused || dry_run ? 0 : ids.size} " \
      "dry_run=#{dry_run} refused=#{refused} max_campaigns=#{max_campaigns} campaign_ids=#{ids.join(',')}"
    )
  end
end
