# frozen_string_literal: true

class LiveChat::Interlocutor < ApplicationRecord
  self.table_name = 'live_chat_interlocutors'

  belongs_to :user, class_name: 'User'
  belongs_to :conversation, class_name: 'LiveChat::Conversation'
end
