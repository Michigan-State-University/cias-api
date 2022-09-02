# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :user

  enum event: { new_message: 0, auto_generated_conversation: 1 }

  validates :data, json: { schema: lambda {
    Rails.root.join("#{json_schema_path}/notification_data.json").to_s
  }, message: lambda { |err|
    err
  } }

  scope :unread_notifications, ->(user_id) { where(user_id: user_id, is_read: false) }

  def mark_as_readed
    update!(is_read: true)
  end

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/notification'
  end
end
