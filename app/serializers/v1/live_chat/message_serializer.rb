# frozen_string_literal: true

class V1::LiveChat::MessageSerializer < V1Serializer
  attributes :id, :content, :conversation_id, :is_read, :created_at

  attribute :interlocutor_id do |object|
    object.live_chat_interlocutor.id
  end
end
