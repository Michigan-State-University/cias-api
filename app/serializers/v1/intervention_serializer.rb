# frozen_string_literal: true

class V1::InterventionSerializer < V1Serializer
  include FileHelper
  attributes :id, :user_id, :type, :name, :status, :shared_to, :organization_id, :google_language_id, :created_at, :updated_at, :published_at,
             :cat_mh_application_id, :cat_mh_organization_id, :cat_mh_pool, :created_cat_mh_session_count, :license_type, :is_access_revoked,
             :additional_text, :original_text, :quick_exit, :current_narrator, :live_chat_enabled

  has_many :sessions, serializer: V1::SessionSerializer
  has_many :collaborators

  cache_options(store: Rails.cache, expires_in: 24.hours)  # temporary length, might be a subject to change

  attribute :first_session_language do |object|
    object.sessions&.first&.google_tts_voice&.google_tts_language&.language_name
  end

  attribute :files do |object|
    files_info(object) if object.files.attached?
  end

  attribute :first_session_language do |object|
    object.sessions&.first&.google_tts_voice&.google_tts_language&.language_name
  end

  attribute :first_session_language do |object|
    object.sessions&.first&.google_tts_voice&.google_tts_language&.language_name
  end

  attribute :first_session_language do |object|
    object.sessions&.first&.google_tts_voice&.google_tts_language&.language_name
  end

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

  attribute :conversations_transcript do |object|
    map_file_data(object.conversations_transcript) if object.conversations_transcript.attached?
  end

  attribute :conversations_present do |object|
    object.conversations.size.positive?
  end

  def self.newest_csv_link(object)
    ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(object.newest_report, only_path: true)
  end

  def self.files_info(object)
    object.files.map do |file|
      map_file_data(file)
    end
  end
end
