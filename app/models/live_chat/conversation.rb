# frozen_string_literal: true

class LiveChat::Conversation < ApplicationRecord
  self.table_name = 'live_chat_conversations'

  belongs_to :intervention, class_name: 'Intervention', counter_cache: true
  has_many :messages, class_name: 'LiveChat::Message', dependent: :destroy
  has_many :live_chat_interlocutors, class_name: 'LiveChat::Interlocutor', dependent: :destroy
  has_many :users, through: :live_chat_interlocutors
  has_many :notifications, as: :notifiable, dependent: :destroy

  has_one_attached :transcript, dependent: :purge_later

  scope :user_conversations, lambda { |user, is_archived|
    scope = LiveChat::Conversation.joins(:live_chat_interlocutors)
    scope = is_archived ? scope.where.not(archived_at: nil) : scope.where(archived_at: nil)
    scope.where(live_chat_interlocutors: { user_id: user.id })
  }

  scope :navigator_conversations, lambda { |user, is_archived = false|
    user_conversations(user, is_archived).
      joins(intervention: :intervention_navigators).
      where(intervention_navigators: { user_id: user.id })
  }

  def archived?
    !archived_at.nil?
  end

  def navigator
    users.limit_to_roles('navigator').first
  end

  def other_user
    (users - [navigator]).first
  end
end
