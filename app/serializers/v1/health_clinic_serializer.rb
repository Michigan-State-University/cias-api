# frozen_string_literal: true

class V1::HealthClinicSerializer < V1Serializer
  attributes :name, :health_system_id

  attribute :deleted do |object|
    object.deleted_at.present?
  end

  has_many :health_clinic_admins, record_type: :user, serializer: V1::UserSerializer
end
