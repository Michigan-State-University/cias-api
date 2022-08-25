# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :user, class_name: 'User'

  alias_attribute :type, :notification_type
  alias_attribute :time_sent, :created_at

  enum notification_type: {
    inform: 0,
    alert: 1
  }
end
