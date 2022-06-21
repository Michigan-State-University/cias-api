# frozen_string_literal: true

class LiveChat::Intervention::NavigatorSetup < ApplicationRecord
  self.table_name = 'live_chat_navigator_setups'

  belongs_to :intervention, dependent: :destroy
  has_many :participant_links, class_name: 'LiveChat::Intervention::ParticipantLink', dependent: :destroy
  has_one :phone, dependent: :nullify

  enum notify_by: { sms: 'sms', email: 'email' }
end
