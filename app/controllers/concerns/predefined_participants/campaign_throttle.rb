# frozen_string_literal: true

module PredefinedParticipants::CampaignThrottle
  extend ActiveSupport::Concern

  private

  def throttle_campaign_request
    return unless Rack::Attack.enabled

    campaign_throttles.each do |dimension, subject, limit, period|
      next unless Rack::Attack.cache.count("sms_campaigns/#{action_name}/#{dimension}:#{subject}", period) > limit

      return render_campaign_throttled(period)
    end
  end

  def campaign_throttles
    settings = Settings.sms_campaigns
    [
      ['user', current_v1_user.id, settings.throttle_user_per_hour, 1.hour.to_i],
      ['intervention', intervention_id.to_s.downcase, settings.throttle_intervention_per_hour, 1.hour.to_i]
    ]
  end

  def render_campaign_throttled(period)
    response.set_header('Retry-After', (period - (Time.current.to_i % period)).to_s)
    render json: { message: I18n.t('predefined_participants.sms_campaigns.errors.rate_limited'),
                   details: { errors: [{ code: 'RATE_LIMITED' }] } },
           status: :too_many_requests
  end
end
