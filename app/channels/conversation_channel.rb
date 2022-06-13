# frozen_string_literal: true

class ConversationChannel < ApplicationCable::Channel
  include CableExceptionHandler

  def subscribed
    user_conversations.find_each do |conversation|
      stream_from channel_id_for(conversation)
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end

  def on_message(data)
    # format will be for example: { 'action' => 'on_message', 'content' => 'this is the content of the message' }
    conversation = LiveChat::Conversation.find(data['conversationId'])
    sender = User.find(data['senderId'])
    interlocutor = LiveChat::Interlocutor.find_or_create_by!(user_id: sender.id, conversation_id: conversation.id)
    begin
      message = LiveChat::Message.create!(conversation: conversation, content: data['content'], live_chat_interlocutor: interlocutor)
      ActionCable.server.broadcast(channel_id_for(conversation), format_message(message))
    rescue ActiveRecord::RecordInvalid
      raise LiveChat::MessageTooLongException.new(
        I18n.t('activerecord.errors.models.live_chat.message.attributes.content.too_long_detailed', max_len: 500, cur_len: data['content'].length),
        channel_id_for(conversation)
      )
    end
  end

  private

  def format_message(message)
    {
      data: V1::LiveChat::MessageSerializer.new(message).serializable_hash,
      topic: 'new-chat-message',
      status: 200
    }
  end

  def channel_id_for(conversation)
    "conversation_channel_#{conversation.id}"
  end

  def user_conversations
    LiveChat::Conversation.includes(:live_chat_interlocutors).where(live_chat_interlocutors: { user_id: current_user.id })
  end
end
