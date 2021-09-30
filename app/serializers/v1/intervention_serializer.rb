# frozen_string_literal: true

class V1::InterventionSerializer < V1Serializer
  attributes :id, :user_id, :name, :status, :shared_to, :organization_id, :google_language_id, :created_at, :updated_at, :published_at

  has_many :sessions, serializer: V1::SessionSerializer

  cache_options(store: Rails.cache, namespace: 'v1-intervention-serializer', expires_in: 24.hours)  # temporary length, might be a subject to change

  attribute :first_session_language do |object|
    object.sessions&.first&.google_tts_voice&.google_tts_language&.language_name
  end

  attribute :csv_link do |object|
    newest_csv_link(object) if object.reports.attached?
  end

  attribute :csv_generated_at do |object|
    object.newest_report.created_at if object.reports.attached?
  end

  attribute :language_name do |object|
    object.google_language.language_name
  end

  attribute :language_code do |object|
    object.google_language.language_code
  end

  attribute :logo_url do |object|
    url_for(object.logo) if object.logo.attached?
  end

  attribute :image_alt do |object|
    object.logo_blob.description if object.logo_blob.present?
  end

  attribute :user do |object|
    object.user.as_json(only: %i[id email first_name last_name])
  end

  attribute :sessions_size do |object|
    object.sessions.size
  end

  attribute :has_cat_sessions do |object|
    object.sessions.exists?(type: 'Session::CatMh')
  end

  def self.newest_csv_link(object)
    ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(object.newest_report, only_path: true)
  end
end
