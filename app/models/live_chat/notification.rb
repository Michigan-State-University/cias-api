# frozen_string_literal: true

class LiveChat::Notification < ApplicationRecord
  self.table_name = 'live_chat_notifications'

  belongs_to :object, polymorphic: true
  belongs_to :user, class_name: 'User'

  enum type: {
    alert: 'alert',
    inform: 'inform'
  }
end
