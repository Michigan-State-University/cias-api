# frozen_string_literal: true

class V1::LiveChat::MessageSerializer < V1Serializer
  attributes :id, :content, :conversation_id

  attribute :user_id do |object|
    object.user.id
  end

  attribute :first_name do |object|
    object.user.first_name
  end

  attribute :last_name do |object|
    object.user.last_name
  end
end
