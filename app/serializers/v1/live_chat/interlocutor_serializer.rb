# frozen_string_literal: true

class V1::LiveChat::InterlocutorSerializer < V1Serializer
  attributes :id, :user_id

  attribute :avatar_url do |object|
    url_for(object.user.avatar) if object.user.avatar.attached?
  end

  attribute :first_name do |object|
    object.user.first_name
  end

  attribute :last_name do |object|
    object.user.last_name
  end
end
