# frozen_string_literal: true

class LiveChat::Interventions::NavigatorSetup < ApplicationRecord
  self.table_name = 'live_chat_navigator_setups'

  belongs_to :intervention, class_name: 'Intervention', dependent: :destroy
  has_many :participant_links, class_name: 'LiveChat::Interventions::ParticipantLink', dependent: :destroy
  has_one :phone, dependent: :nullify

  enum notify_by: { email: 0, sms: 1 }
end
