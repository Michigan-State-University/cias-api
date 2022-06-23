# frozen_string_literal: true

class ConversationChannel < ApplicationCable::Channel
  include CableExceptionHandler

  def subscribed
    stream_from current_channel_id
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end

  def on_message_sent(data)
    # format will be for example: { 'action' => 'on_message', 'content' => 'this is the content of the message' }
    conversation = LiveChat::Conversation.find(data['conversationId'])
    sender = LiveChat::Interlocutor.find(data['interlocutorId'])
    begin
      message = LiveChat::Message.create!(conversation: conversation, content: data['content'], live_chat_interlocutor: sender)
      conversation.live_chat_interlocutors.each do |interlocutor|
        ActionCable.server.broadcast(user_channel_id(interlocutor.user), format_chat_message(message))
      end
    rescue ActiveRecord::RecordInvalid
      raise LiveChat::MessageTooLongException.new(
        I18n.t('activerecord.errors.models.live_chat.message.attributes.content.too_long_detailed', max_len: 500, cur_len: data['content'].length),
        current_channel_id,
        conversation.id
      )
    end
  end

  def on_message_read(data)
    message = LiveChat::Message.find(data['messageId'])
    message.update!(is_read: true)
    conversation = message.conversation
    response = generic_message({ messageId: message.id, conversationId: conversation.id }, 'message_read')
    conversation.live_chat_interlocutors.each do |interlocutor|
      ActionCable.server.broadcast(user_channel_id(interlocutor.user), response)
    end
  end

  def on_conversation_created(data)
    interlocutors = [LiveChat::Interlocutor.new(user_id: data['userId']), LiveChat::Interlocutor.new(user_id: current_user.id)]
    conversation = LiveChat::Conversation.create!(live_chat_interlocutors: interlocutors)
    response = generic_message(V1::LiveChat::ConversationSerializer.new(conversation, { include: %i[live_chat_interlocutors] }).serializable_hash,
                               'conversation_created')
    ActionCable.server.broadcast(current_channel_id, response)
    ActionCable.server.broadcast("user_conversation_channel_#{data['userId']}", response)
  end

  private

  def format_chat_message(message)
    generic_message(V1::LiveChat::MessageSerializer.new(message).serializable_hash, 'message_sent')
  end

  def generic_message(payload, topic, status = 200)
    {
      data: payload,
      topic: topic,
      status: status
    }
  end

  def user_channel_id(user)
    "user_conversation_channel_#{user.id}"
  end

  def current_channel_id
    @current_channel_id ||= user_channel_id(current_user)
  end
end
