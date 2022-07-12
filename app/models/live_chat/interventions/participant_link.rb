# frozen_string_literal: true

class LiveChat::Interventions::ParticipantLink < ApplicationRecord
  self.table_name = 'live_chat_participant_links'

  belongs_to :navigator_setup, class_name: 'LiveChat::Interventions::NavigatorSetup'
  validates :url, length: { maximum: 2048 }
  default_scope { order(created_at: :desc) }
end
