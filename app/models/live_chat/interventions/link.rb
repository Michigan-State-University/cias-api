# frozen_string_literal: true

class LiveChat::Interventions::Link < ApplicationRecord
  self.table_name = 'live_chat_links'

  belongs_to :navigator_setup, class_name: 'LiveChat::Interventions::NavigatorSetup'
  validates :url, length: { maximum: 2048 }
  default_scope { order(created_at: :desc) }

  enum link_for: { participants: 0, navigators: 1 }

  scope :for_participants, -> { where(link_for: :participant) }
  scope :for_navigators, -> { where(link_for: :navigators) }
end
