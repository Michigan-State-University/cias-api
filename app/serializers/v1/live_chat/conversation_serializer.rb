# frozen_string_literal: true

class V1::LiveChat::ConversationSerializer < V1Serializer
  attributes :id

  attribute :last_message do |object|
    V1::LiveChat::MessageSerializer.new(object.messages.last).serializable_hash
  end

  attribute :interlocutors do |object|
    V1::LiveChat::InterlocutorSerializer.new(object.live_chat_interlocutors).serializable_hash
  end
end
