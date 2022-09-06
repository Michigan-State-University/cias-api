# frozen_string_literal: true

class V1::NotifyService
  include MessageHandler

  def self.call(notification)
    new(notification).call
  end

  def initialize(notification)
    @notification = notification
  end

  attr_reader :notification

  def call
    notification_channel = "notification_channel_#{notification.user.id}"

    ActionCable.server.broadcast(notification_channel,
                                 generic_message(V1::NotificationSerializer.new(notification).serializable_hash, "#{notification.event}_notification"))
  end
end
