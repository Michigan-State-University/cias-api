# frozen_string_literal: true

class LiveChat::Conversation < ApplicationRecord
  self.table_name = 'live_chat_conversations'

  belongs_to :intervention, class_name: 'Intervention'
  has_many :messages, class_name: 'LiveChat::Message', dependent: :destroy
  has_many :live_chat_interlocutors, class_name: 'LiveChat::Interlocutor', dependent: :destroy
  has_many :users, through: :live_chat_interlocutors
  has_many :notifications, dependent: :destroy

  scope :user_conversations, lambda { |user, is_archived|
    LiveChat::Conversation.joins(:live_chat_interlocutors).where(archived: is_archived, live_chat_interlocutors: { user_id: user.id })
  }

  scope :navigator_conversations, lambda { |user, is_archived = false|
    user_conversations(user, is_archived).
      joins(intervention: :intervention_navigators).
      where(intervention_navigators: { user_id: user.id })
  }
end
