# frozen_string_literal: true

class NotificationChannel < ApplicationCable::Channel
  after_subscribe -> { current_user.update!(online: true) }
  after_unsubscribe -> { current_user.update!(online: false) }

  def subscribed
    stream_from "notification_channel_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
