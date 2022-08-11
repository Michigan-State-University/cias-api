# frozen_string_literal: true

class ConversationChannel < ApplicationCable::Channel
  include CableExceptionHandler

  def subscribed
    stream_from current_channel_id
    if intervention_id.present? # rubocop:disable Style/GuardClause
      if no_navigator_available?(intervention_id)
        ActionCable.server.broadcast(current_channel_id,
                                     generic_message({}, 'navigator_unavailable', 404))
      end
      stream_from intervention_channel_id(intervention_id)
    end
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
    rescue ActiveRecord::RecordInvalid => e
      raise LiveChat::OperationInvalidException.new(
        e.record.errors.map(&:message),
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
    navigator = fetch_available_navigator(data['interventionId'])
    interlocutors = [LiveChat::Interlocutor.new(user_id: navigator.id), LiveChat::Interlocutor.new(user_id: current_user.id)]
    conversation = LiveChat::Conversation.create!(live_chat_interlocutors: interlocutors, intervention_id: data['interventionId'])
    conversation.messages << LiveChat::Message.new(content: data['firstMessageContent'], live_chat_interlocutor: interlocutors[1])
    response = generic_message(V1::LiveChat::ConversationSerializer.new(conversation, { include: %i[live_chat_interlocutors] }).serializable_hash,
                               'conversation_created')
    ActionCable.server.broadcast(current_channel_id, response)
    ActionCable.server.broadcast(user_channel_id(navigator), response)
  end

  def on_conversation_archived(data)
    # this event should only fire when navigator ends the conversation; therefore, current user should always be a navigator
    conversation = LiveChat::Conversation.find(data['conversationId'])
    conversation.update!(archived: true)
    response = generic_message({ conversationId: conversation.id }, 'conversation_archived')
    conversation.users.each do |user|
      ActionCable.server.broadcast(user_channel_id(user), response)
    end
  end

  def on_fetch_live_chat_setup(data)
    intervention = Intervention.find(data['interventionId'])
    setup = intervention.navigator_setup
    response_data = V1::LiveChat::Interventions::LiveChatSetupSerializer.new(setup, { include: %i[participant_links phone] })
    ActionCable.server.broadcast(current_channel_id, generic_message(response_data, 'live_chat_setup_fetched'))
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

  def intervention_channel_id(intervention_id)
    "intervention_channel_#{intervention_id}"
  end

  def user_channel_id(user)
    "user_conversation_channel_#{user.id}"
  end

  def current_channel_id
    @current_channel_id ||= user_channel_id(current_user)
  end

  def fetch_available_navigator(intervention_id)
    active_navigators = fetch_online_navigators(intervention_id)
    if active_navigators.empty?
      raise LiveChat::NavigatorUnavailableException.new(I18n.t('activerecord.errors.models.live_chat.conversation.no_navigator_available'),
                                                        current_channel_id)
    end

    active_navigators.first
  end

  def no_navigator_available?(intervention_id)
    !Intervention.find(intervention_id).navigators.exists?(online: true)
  end

  def fetch_online_navigators(intervention_id)
    intervention = Intervention.find(intervention_id)
    intervention.navigators.
          where(online: true).
          includes(:conversations).
          sort_by { |user| user.conversations.where(archived: false).count }
  end

  def intervention_id
    params[:intervention_id]
  end
end
