# frozen_string_literal: true

class V1::Notifications::Message
  def self.call(conversation, message)
    new(conversation, message).call
  end

  def initialize(conversation, message)
    @user = conversation.navigator
    @conversation = conversation
    @message = message
  end

  attr_reader :user, :conversation, :message

  def call
    create_notification unless connected_to_channel?
  end

  private

  def connected_to_channel?
    redis_client = Redis.new
    redis_client.pubsub('channels', "*user_conversation_channel_#{user.id}").present?
  end

  def create_notification
    Notification.create!(user: user, notifiable: conversation, event: :new_conversation, data: generate_notification_body)
  end

  def generate_notification_body
    {
      conversation_id: conversation.id,
      user_id: participant.id,
      avatar_url: participant.avatar.attached? ? url_for(participant.avatar) : '',
      first_name: participant.first_name || '',
      last_name: participant.last_name || '',
      message: message.content
    }
  end

  def participant
    @participant ||= conversation.users.where.not(id: user.id).first
  end
end
