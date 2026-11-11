# frozen_string_literal: true

class V1::Interventions::PredefinedParticipants::SmsCampaignsController < V1Controller
  include ::PredefinedParticipants::CampaignThrottle
  include ::PredefinedParticipants::InterventionGate

  before_action :verify_access
  before_action :require_current_editor
  before_action :throttle_campaign_request, only: %i[create cancel]

  def index
    render json: serialized_response(paginate(campaigns, pagination_params), 'PredefinedParticipants::SmsCampaign')
  end

  def create
    campaign = V1::PredefinedParticipants::SmsCampaigns::CreateService.call(intervention_load, current_v1_user, campaign_params)

    render json: serialized_response(campaign, 'PredefinedParticipants::SmsCampaign'), status: :accepted
  end

  def cancel
    campaign = V1::PredefinedParticipants::SmsCampaigns::CancelService.call(intervention_load.sms_campaigns.find(params[:id]))

    render json: serialized_response(campaign, 'PredefinedParticipants::SmsCampaign')
  end

  def meta
    render json: {
      personal_link_template: ::PredefinedUserParameter.personal_link(':slug'),
      personal_link_expected_length: body_length.personal_link_expected_length,
      tracked_link_template: ::SmsLinksUser.tracked_link(':slug'),
      tracked_link_expected_length: body_length.tracked_link_expected_length,
      gsm7_segment_lengths: body_length::GSM7_SEGMENT_LENGTHS,
      ucs2_segment_lengths: body_length::UCS2_SEGMENT_LENGTHS,
      max_body_length: Settings.sms_campaigns.max_body_length,
      max_segments: Settings.sms_campaigns.max_segments,
      max_reminder_days_after: Settings.sms_campaigns.max_reminder_days_after
    }
  end

  private

  def campaigns
    intervention_load.sms_campaigns.preload(:parent_campaign).order(created_at: :desc, id: :desc)
  end

  def pagination_params
    { per_page: params[:per_page].presence || Settings.sms_campaigns.default_per_page, page: params[:page] }
  end

  def campaign_params
    params.expect(sms_campaign: [:kind, :body, { links: [%i[url variable link_type]],
                                                 scheduled_reminder: [:body, :days_after, { links: [%i[url variable link_type]] }] }])
  end

  def body_length
    V1::PredefinedParticipants::SmsCampaigns::BodyLength
  end
end
