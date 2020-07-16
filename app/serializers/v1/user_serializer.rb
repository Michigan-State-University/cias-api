# frozen_string_literal: true

class V1::UserSerializer < V1Serializer
  attributes :email, :full_name, :first_name, :last_name, :phone, :deactivated, :roles
end
