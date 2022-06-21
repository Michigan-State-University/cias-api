# frozen_string_literal: true

class LiveChat::Intervention::ParticipantLink < ApplicationRecord
  self.table_name = 'live_chat_participant_links'

  belongs_to :navigator_setup, class_name: 'LiveChat::Intervention::NavigatorSetup'
  validates :url, length: { maximum: 2048 }
end
