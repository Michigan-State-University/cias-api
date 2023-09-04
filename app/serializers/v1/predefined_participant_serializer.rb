# frozen_string_literal: true

class V1::PredefinedParticipantSerializer < V1Serializer
  attributes :full_name, :first_name, :last_name

  attribute :phone do |object|
    object.phone.as_json(only: %i[iso prefix number confirmed])
  end

  attribute :slug do |object|
    object.predefined_user_parameter.slug
  end

  attribute :health_clinic_id do |object|
    object.predefined_user_parameter.health_clinic_id
  end
end
