# frozen_string_literal: true

class V1::CollaboratorSerializer < V1Serializer
  attributes :id, :view, :edit, :data_access

  attribute :user, if: proc { |_record, params| !params[:skip_user_data] } do |collaborator|
    V1::SimpleUserSerializer.new(collaborator.user).to_hash[:data][:attributes]
  end
end
