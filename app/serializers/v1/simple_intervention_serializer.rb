# frozen_string_literal: true

class V1::SimpleInterventionSerializer < V1Serializer
  include TeamCollaboratorsHelper
  attributes :id, :user_id, :name, :status, :created_at, :updated_at, :organization_id, :google_language_id

  cache_options(store: Rails.cache, expires_in: 24.hours)  # temporary length, might be a subject to change

  attribute :sessions_size do |object|
    object.sessions.size
  end
end
