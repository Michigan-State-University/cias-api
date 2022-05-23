# frozen_string_literal: true

class LiveChat::Conversation < ApplicationRecord
  self.table_name = 'live_chat_conversations'

  has_many :messages, class_name: 'LiveChat::Message', dependent: :destroy
  has_many :live_chat_interlocutors, class_name: 'LiveChat::Interlocutor', dependent: :destroy
  has_many :users, through: :live_chat_interlocutors
end
