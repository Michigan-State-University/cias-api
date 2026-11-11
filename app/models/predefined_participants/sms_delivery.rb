# frozen_string_literal: true

class PredefinedParticipants::SmsDelivery < ApplicationRecord
  self.table_name = 'predefined_participants_sms_deliveries'

  belongs_to :campaign, class_name: 'PredefinedParticipants::SmsCampaign', inverse_of: :deliveries
  belongs_to :predefined_user_parameter, inverse_of: :sms_deliveries
  belongs_to :message, optional: true

  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed' }, validate: true

  audited except: %i[body]

  def self.claim(campaign_id:, predefined_user_parameter_id:, body:)
    delivery = new(campaign_id: campaign_id, predefined_user_parameter_id: predefined_user_parameter_id, body: body, status: 'pending')
    delivery.save!(validate: false)
    delivery
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
