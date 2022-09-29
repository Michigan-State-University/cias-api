# frozen_string_literal: true

class V1::UserSerializer < V1Serializer
  attributes :id, :email, :full_name, :first_name, :last_name, :description, :sms_notification, :time_zone, :active, :roles,
             :avatar_url, :phone, :team_id, :admins_team_ids, :feedback_completed, :email_notification, :organizable_id, :quick_exit_enabled

  cache_options store: Rails.cache, expires_in: 24.hours

  has_one :hfhs_patient_detail, serializer: V1::HfhsPatientDetailSerializer

  attribute :avatar_url do |object|
    polymorphic_url(object.avatar) if object.avatar.attached?
  end

  attribute :phone do |object|
    object.phone.as_json(only: %i[iso prefix number confirmed])
  end

  attribute :team_name do |object|
    object.team&.name
  end

  attribute :health_clinics_ids do |object|
    object.user_health_clinics.select(:id) if object.role?('health_clinic_admin')
  end
end
