# frozen_string_literal: true

class V1::SimpleUserSerializer < V1Serializer
  attributes :id, :email, :full_name, :first_name, :last_name
end
