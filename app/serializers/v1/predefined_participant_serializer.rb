# frozen_string_literal: true

class V1::PredefinedParticipantSerializer < V1Serializer
  attributes :full_name, :first_name, :last_name

  attribute :phone do |object|
    object.phone.as_json(only: %i[iso prefix number confirmed])
  end

  # attribute :slug do |object|
  #   object.predefined_user_parameter.slug
  # end
  #
  # attribute :auto_invitation do |object|
  #   object.predefined_user_parameter.auto_invitation
  # end
  #
  # attribute :invitation_sent_at do |object|
  #   object.predefined_user_parameter.invitation_sent_at
  # end
  #
  # attribute :health_clinic_id do |object|
  #   object.predefined_user_parameter.health_clinic_id
  # end

  %i[slug auto_invitation invitation_sent_at health_clinic_id].each do |attr|
    attribute attr do |object|
      object.predefined_user_parameter.send(attr)
    end
  end
end
