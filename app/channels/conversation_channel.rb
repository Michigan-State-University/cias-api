# frozen_string_literal: true

class ConversationChannel < ApplicationCable::Channel
  include CableExceptionHandler
  include MessageHandler

  def subscribed
    stream_from current_channel_id
    if intervention_id.present? # rubocop:disable Style/GuardClause
      if no_navigator_available?(intervention_id)
        ensure_confirmation_sent
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
    conversation = fetch_conversation(data)
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

  def on_current_screen_title_changed(data)
    conversation = fetch_conversation(data)
    conversation.participant_location_history << data['currentLocation'] if conversation.participant_location_history.last != data['currentLocation']
    conversation.update!(current_screen_title: data['currentScreenTitle'])
    response = generic_message({ currentScreenTitle: conversation.current_screen_title, conversationId: conversation.id }, 'current_screen_title_changed')
    navigator = fetch_conversation_navigator(conversation)
    ActionCable.server.broadcast(user_channel_id(navigator), response)
  end

  def on_conversation_created(data)
    navigator = fetch_available_navigator(data['interventionId'])
    handle_summoning_user(current_user, data, navigator)
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
    conversation = fetch_conversation(data)
    conversation.update!(archived_at: DateTime.now)
    response = generic_message({ conversationId: conversation.id, archivedAt: conversation.archived_at }, 'conversation_archived')
    conversation.users.each do |user|
      ActionCable.server.broadcast(user_channel_id(user), response)
    end
  end

  def on_fetch_live_chat_setup(data)
    intervention = fetch_intervention(data)
    setup = intervention.navigator_setup
    response_data = V1::LiveChat::Interventions::LiveChatSetupSerializer.new(setup, { include: %i[participant_links phone message_phone] })
    ActionCable.server.broadcast(current_channel_id, generic_message(response_data, 'live_chat_setup_fetched'))
  end

  def on_call_out_navigator(data)
    intervention = fetch_intervention(data)
    summoning_user = summoning_user(current_user.id, intervention.id) ||
                     LiveChat::SummoningUser.create!(user_id: current_user.id, intervention_id: intervention.id)

    # Uncomment to prevent navigator call out for given conditions
    # unless summoning_user.present? && summoning_user.call_out_available?
    # unlock_time = summoning_user.unlock_next_call_out_time
    # raise LiveChat::CallOutUnavailableException.new('Unavailable to call out navigator', current_channel_id, unlock_time)
    # end

    # Update "unlock_next_call_out_time" to a time when next call out will be available
    summoning_user.update!(participant_handled: false)
    V1::LiveChat::Interventions::Navigators::SendMessages.call(intervention, 'call_out')
    response_data = { unlockTime: summoning_user.unlock_next_call_out_time }
    ActionCable.server.broadcast(current_channel_id, generic_message(response_data, 'navigators_called_out'))
  end

  def on_cancel_call_out(data)
    handle_summoning_user(current_user, data)
    summoning_user = summoning_user(current_user, data['interventionId'])
    response_data = { summoningUserId: summoning_user&.id }
    ActionCable.server.broadcast(current_channel_id, generic_message(response_data, 'call_out_canceled'))
  end

  private

  def format_chat_message(message)
    generic_message(V1::LiveChat::MessageSerializer.new(message).serializable_hash, 'message_sent')
  end

  def intervention_channel_id(intervention_id)
    "navigators_in_intervention_channel_#{intervention_id}"
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
          sort_by { |user| user.conversations.where(archived_at: nil).count }
  end

  def fetch_intervention(data)
    Intervention.find(data['interventionId'])
  end

  def fetch_conversation_navigator(conversation)
    conversation.users.limit_to_roles('navigator').first
  end

  def fetch_conversation(data)
    LiveChat::Conversation.find(data['conversationId'])
  end

  def handle_summoning_user(participant, data, user_to_ignore = nil)
    intervention = fetch_intervention(data)
    summoning_user = summoning_user(participant.id, intervention.id)
    return if summoning_user.nil? || summoning_user.participant_handled

    V1::LiveChat::Interventions::Navigators::SendMessages.call(intervention, 'cancel_call_out', user_to_ignore)
    summoning_user.update!(participant_handled: true)
  end

  def summoning_user(user_id, intervention_id)
    return @summoning_user if defined?(@summoning_user)

    @summoning_user = LiveChat::SummoningUser.find_by(user_id: user_id, intervention_id: intervention_id)
  end

  def intervention_id
    params[:intervention_id]
  end
end
