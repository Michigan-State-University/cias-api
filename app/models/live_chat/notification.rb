# frozen_string_literal: true

class LiveChat::Notification < ApplicationRecord
  extend DefaultValues

  self.table_name = 'live_chat_notifications'

  belongs_to :notifiable, polymorphic: true
  belongs_to :user, class_name: 'User'

  attribute :notification_params, :json, default: assign_default_values('notification_params')

  enum notification_type: {
    alert: 'alert',
    inform: 'inform'
  }
end
