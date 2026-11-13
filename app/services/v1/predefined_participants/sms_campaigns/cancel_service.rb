# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
class V1::PredefinedParticipants::SmsCampaigns::CancelService
  JOB_CLASS = 'PredefinedParticipants::SendSmsCampaignJob'
  NOT_CANCELLABLE_CODE = 'CAMPAIGN_NOT_CANCELLABLE'

  def self.call(campaign)
    new(campaign).call
  end

  def initialize(campaign)
    @campaign = campaign
  end

  def call
    cancel!
    remove_scheduled_job
    campaign.reload
  end

  private

  attr_reader :campaign

  def cancel!
    cancelled = ::PredefinedParticipants::SmsCampaign.where(id: campaign.id, status: 'scheduled')
                                                     .update_all(status: 'cancelled', updated_at: Time.current)
    return if cancelled.positive?

    raise ComplexException.new(I18n.t('predefined_participants.sms_campaigns.errors.not_cancellable'),
                               { errors: [{ code: NOT_CANCELLABLE_CODE }] }, :conflict)
  end

  def remove_scheduled_job
    Sidekiq::ScheduledSet.new.scan(campaign.id).each { |entry| entry.delete if own_job?(entry) }
  rescue StandardError => e
    Rails.logger.error("[#{self.class.name}] scheduled job scan failed: campaign_id=#{campaign.id} error=#{e.class}")
    Sentry.capture_exception(e, extra: { campaign_id: campaign.id })
  end

  def own_job?(entry)
    payload = entry.args.first
    payload.is_a?(Hash) && payload['job_class'] == JOB_CLASS && Array(payload['arguments']).first == campaign.id
  end
end
# rubocop:enable Rails/SkipsModelValidations
