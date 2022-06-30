# frozen_string_literal: true

class V1::LiveChat::ConversationSerializer < V1Serializer
  attributes :id, :intervention_id

  has_many :live_chat_interlocutors, serializer: V1::LiveChat::InterlocutorSerializer

  attribute :last_message do |object|
    last_message = object.messages.last
    if last_message.nil?
      nil
    else
      {
        id: last_message.id,
        content: last_message.content,
        interlocutor_id: last_message.live_chat_interlocutor.id,
        conversation_id: object.id,
        created_at: last_message.created_at,
        is_read: last_message.is_read
      }
    end
  end

  attribute :intervention_name do |object|
    object.intervention.name
  end
end
