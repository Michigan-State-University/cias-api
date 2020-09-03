# frozen_string_literal: true

class V1::UserSerializer < V1Serializer
  attributes :email, :full_name, :first_name, :last_name, :phone, :time_zone, :deactivated, :roles

  attribute :address_attributes do |object|
    object&.address&.attributes&.without(*Address::ATTRS_NO_TO_SERIALIZE) || Address.attrs_to_nil
  end
end
