# frozen_string_literal: true

class V1::UserSerializer < V1Serializer
  attributes :email, :full_name, :first_name, :last_name, :sms_notification, :time_zone, :active, :roles,
             :avatar_url, :phone, :team_id, :admins_team_ids, :feedback_completed, :email_notification

  attribute :avatar_url do |object|
    polymorphic_url(object.avatar) if object.avatar.attached?
  end

  attribute :phone do |object|
    object.phone.as_json(only: %i[iso prefix number confirmed])
  end

  attribute :team_name do |object|
    object.team&.name
  end
end
