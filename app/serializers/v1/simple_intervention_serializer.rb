# frozen_string_literal: true

class V1::SimpleInterventionSerializer < V1Serializer
  include TeamCollaboratorsHelper
  attributes :id, :user_id, :name, :status, :created_at, :updated_at, :organization_id, :google_language_id

  cache_options(store: Rails.cache, namespace: 'simple-intervention-serializer', expires_in: 24.hours) # temporary length, might be a subject to change

  attribute :user do |object|
    object.user.as_json(only: %i[id email first_name last_name])
  end

  attribute :starred do |object, params|
    object.id.in? params[:starred_interventions_ids]
  end

  attribute :sessions_size do |object|
    object.sessions.size
  end

  def self.record_cache_options(options, fieldset, include_list, params)
    return super(options, fieldset, include_list, params) if params[:current_user_id].blank?

    options = options.dup
    options[:namespace] += ":#{params[:current_user_id]}"
  end
end
