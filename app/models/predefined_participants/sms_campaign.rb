# frozen_string_literal: true

class PredefinedParticipants::SmsCampaign < ApplicationRecord
  self.table_name = 'predefined_participants_sms_campaigns'

  belongs_to :intervention, inverse_of: :sms_campaigns
  belongs_to :author, class_name: 'User', optional: true
  belongs_to :parent_campaign, class_name: 'PredefinedParticipants::SmsCampaign', optional: true,
                               inverse_of: :scheduled_reminder
  has_one :scheduled_reminder, class_name: 'PredefinedParticipants::SmsCampaign', foreign_key: :parent_campaign_id,
                               inverse_of: :parent_campaign, dependent: :destroy
  has_many :sms_links, class_name: 'SmsLink', foreign_key: :campaign_id, inverse_of: :campaign, dependent: :destroy
  has_many :deliveries, class_name: 'PredefinedParticipants::SmsDelivery', foreign_key: :campaign_id,
                        inverse_of: :campaign, dependent: :destroy

  enum :kind, { invitation: 'invitation',
                manual_reminder: 'manual_reminder',
                scheduled_reminder: 'scheduled_reminder' },
       validate: true
  enum :status, { scheduled: 'scheduled',
                  sending: 'sending', sent: 'sent',
                  failed: 'failed',
                  cancelled: 'cancelled',
                  skipped: 'skipped' },
       validate: true

  OPEN_STATUSES = %w[scheduled sending].freeze
  NOT_SENDING_STATUSES = %w[cancelled skipped].freeze

  validates :body, presence: true
  validates :scheduled_at, presence: true

  audited except: %i[body]

  def reminder_scheduled_at(from, days_after)
    from.in_time_zone(author_time_zone) + days_after.days
  end

  def anchor_scheduled_reminder!(sent_at)
    reminder = scheduled_reminder
    return unless sent? && reminder&.days_after

    self.class.where(id: reminder.id, status: 'scheduled').update_all( # rubocop:disable Rails/SkipsModelValidations
      scheduled_at: reminder_scheduled_at(sent_at, reminder.days_after), updated_at: Time.current
    )
  end

  def transition_to(status)
    self.class.where(id: id, status: OPEN_STATUSES).update_all(status: status, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def record_recipients_count(total)
    self.class.where(id: id, recipients_count: nil).update_all(recipients_count: total) # rubocop:disable Rails/SkipsModelValidations
  end

  def close!(now = Time.current)
    closed = self.class.where(id: id, status: 'sending').update_all( # rubocop:disable Rails/SkipsModelValidations
      ["status = CASE WHEN accepted_count > 0 THEN 'sent' ELSE 'failed' END, sent_at = ?, updated_at = ?", now, now]
    )
    reload.anchor_scheduled_reminder!(now) if closed.positive?
    closed
  end

  private

  def author_time_zone
    ActiveSupport::TimeZone[author&.time_zone.to_s] || Time.zone
  end
end
