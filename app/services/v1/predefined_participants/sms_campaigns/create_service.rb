# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::CreateService
  def self.call(intervention, author, params)
    new(intervention, author, params).call
  end

  def initialize(intervention, author, params)
    @intervention = intervention
    @author = author
    @params = params
  end

  def call
    V1::PredefinedParticipants::AssertPublished.call(intervention)
    V1::PredefinedParticipants::SmsCampaigns::PayloadValidator.call(attributes)
    campaign = build_campaign
    recipients_count = ::PredefinedParticipants::SmsRecipientsQuery.call(campaign).count
    raise_error(:no_recipients, 'NO_RECIPIENTS', :unprocessable_content) if recipients_count.zero?

    V1::PredefinedParticipants::SmsCampaigns::DailyCap.enforce!(intervention, recipients_count)
    campaign.recipients_count = recipients_count
    persist!(campaign)
    enqueue(campaign)
    enqueue(campaign.scheduled_reminder, at: campaign.scheduled_reminder.scheduled_at) if campaign.scheduled_reminder
    campaign
  end

  private

  attr_reader :intervention, :author, :params

  def attributes
    @attributes ||= V1::PredefinedParticipants::SmsCampaigns::CampaignAttributes.new(params)
  end

  def build_campaign
    campaign = ::PredefinedParticipants::SmsCampaign.new(
      intervention: intervention, author: author, kind: attributes.kind, body: attributes.body, status: 'scheduled',
      scheduled_at: Time.current
    )
    build_reminder(campaign) if attributes.reminder.present?
    campaign
  end

  def build_reminder(campaign)
    days_after = attributes.days_after
    campaign.build_scheduled_reminder(
      intervention: intervention, author: author, kind: 'scheduled_reminder', body: attributes.reminder_body, status: 'scheduled',
      days_after: days_after, scheduled_at: campaign.reminder_scheduled_at(campaign.scheduled_at, days_after)
    )
  end

  def persist!(campaign)
    ActiveRecord::Base.transaction do
      save_campaign!(campaign)
      attributes.links.each { |link| campaign.sms_links.create!(link) }
      attributes.reminder_links.each { |link| campaign.scheduled_reminder.sms_links.create!(link) } if campaign.scheduled_reminder
    end
  rescue ActiveRecord::RecordInvalid
    raise_error(:invalid_payload, 'INVALID_LINK', :unprocessable_content)
  end

  def save_campaign!(campaign)
    campaign.save!
  rescue ActiveRecord::RecordNotUnique
    raise_error(:campaign_in_progress, 'CAMPAIGN_IN_PROGRESS', :conflict)
  end

  def enqueue(campaign, at: nil)
    job = at ? ::PredefinedParticipants::SendSmsCampaignJob.set(wait_until: at) : ::PredefinedParticipants::SendSmsCampaignJob
    return if job.perform_later(campaign.id)

    Sentry.capture_message('SMS campaign job was not enqueued', extra: { campaign_id: campaign.id })
  rescue StandardError => e
    Sentry.capture_exception(e)
    Rails.logger.error("[#{self.class.name}] enqueue failed: campaign_id=#{campaign.id} error=#{e.class}")
  end

  def raise_error(message_key, code, status)
    raise ComplexException.new(
      I18n.t("predefined_participants.sms_campaigns.errors.#{message_key}"), { errors: [{ code: code }] }, status
    )
  end
end
