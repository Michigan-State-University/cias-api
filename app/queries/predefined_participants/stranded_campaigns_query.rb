# frozen_string_literal: true

class PredefinedParticipants::StrandedCampaignsQuery
  OPEN_STATUSES = ::PredefinedParticipants::SmsCampaign::OPEN_STATUSES
  STALE_AFTER = ::PredefinedParticipants::SendSmsCampaignJob::RECLAIM_AFTER

  def self.call(now = Time.current)
    new(now).call
  end

  def initialize(now = Time.current)
    @now = now
  end

  def call
    ::PredefinedParticipants::SmsCampaign.where(status: OPEN_STATUSES)
                                         .where(scheduled_at: ..now)
                                         .where(updated_at: ...(now - STALE_AFTER))
  end

  private

  attr_reader :now
end
