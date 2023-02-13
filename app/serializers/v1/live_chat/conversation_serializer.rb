# frozen_string_literal: true

class V1::LiveChat::ConversationSerializer < V1Serializer
  include FileHelper
  attributes :id, :intervention_id, :current_screen_title, :archived_at

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

  attribute :transcript do |object|
    map_file_data(object.transcript, ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC')) if object.transcript.attached?
  end
end
