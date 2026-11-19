# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::ReconcileStrandedCampaigns
  BATCH_SIZE = 500
  MAX_CAMPAIGNS_PER_RUN = 100
  JOB_CLASS = ::PredefinedParticipants::SendSmsCampaignJob.name

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
    future = unqueued_future_campaigns
    found = candidates.count + future.size
    refused = refuse?(found)
    dispatch = !dry_run && !refused
    ids = collect_ids(candidates, dispatch: dispatch) + requeue_future(future, dispatch: dispatch)

    log(found, ids, refused)

    Result.new(found: found, enqueued: dispatch ? ids.size : 0, dry_run: dry_run, refused: refused,
               max_campaigns: max_campaigns, candidate_ids: ids)
  end

  private

  attr_reader :dry_run, :now, :max_campaigns

  def refuse?(found)
    !dry_run && max_campaigns.present? && found > max_campaigns
  end

  # A campaign whose time has not come needs a job only if Redis lost the one it was given.
  def unqueued_future_campaigns
    ::PredefinedParticipants::SmsCampaign.where(status: 'scheduled').where('scheduled_at > ?', now)
                                         .where.not(id: queued_campaign_ids.to_a).pluck(:id, :scheduled_at)
  end

  def queued_campaign_ids
    Sidekiq::ScheduledSet.new.each_with_object(Set.new) do |entry, ids|
      payload = entry.args.first
      ids << Array(payload['arguments']).first if payload.is_a?(Hash) && payload['job_class'] == JOB_CLASS
    end
  end

  def requeue_future(future, dispatch:)
    future.map do |campaign_id, scheduled_at|
      ::PredefinedParticipants::SendSmsCampaignJob.set(wait_until: scheduled_at).perform_later(campaign_id) if dispatch
      campaign_id
    end
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
