# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorSerializer < V1Serializer
  attributes :first_name, :last_name, :email

  attribute :avatar_url do |object|
    polymorphic_url(object.avatar) if object.avatar.attached?
  end
end
