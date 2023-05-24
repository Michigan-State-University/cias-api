# frozen_string_literal: true

class V1::CollaboratorSerializer < V1Serializer
  attributes :id, :view, :edit, :data_access

  attribute :user do |collaborator|
    V1::SimpleUserSerializer.new(collaborator.user).to_hash[:data][:attributes]
  end
end
