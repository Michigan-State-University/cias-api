# frozen_string_literal: true

class V1::PredefinedParticipantSerializer < V1Serializer
  attributes :full_name, :first_name, :last_name, :email

  attribute :phone do |object|
    object.phone.as_json(only: %i[iso prefix number confirmed])
  end

  %i[slug auto_invitation invitation_sent_at health_clinic_id external_id].each do |attr|
    attribute attr do |object|
      object.predefined_user_parameter.send(attr)
    end
  end
end
