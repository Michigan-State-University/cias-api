# frozen_string_literal: true

class LiveChat::Message < ApplicationRecord
  self.table_name = 'live_chat_messages'

  belongs_to :conversation, class_name: 'LiveChat::Conversation'
  belongs_to :live_chat_interlocutor, class_name: 'LiveChat::Interlocutor'
  delegate :user, to: :live_chat_interlocutor
end
