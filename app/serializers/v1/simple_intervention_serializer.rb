# frozen_string_literal: true

class V1::SimpleInterventionSerializer < V1Serializer
  include TeamCollaboratorsHelper
  attributes :id, :user_id, :name, :status, :created_at, :updated_at, :organization_id, :google_language_id,
             :cat_mh_pool, :license_type, :cat_mh_application_id, :cat_mh_organization_id, :is_access_revoked, :created_cat_mh_session_count,
             :hfhs_access

  cache_options(store: Rails.cache, namespace: 'simple-intervention-serializer', expires_in: 24.hours)  # temporary length, might be a subject to change

  has_many :clinic_locations, serializer: V1::ClinicLocationSerializer

  attribute :user do |object|
    object.user.as_json(only: %i[id email first_name last_name])
  end

  attribute :sessions_size do |object|
    object.sessions.size
  end
end
