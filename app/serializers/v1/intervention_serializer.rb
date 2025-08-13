# frozen_string_literal: true

class V1::InterventionSerializer < V1Serializer
  include FileHelper
  include TeamCollaboratorsHelper

  attributes :id, :user_id, :type, :name, :status, :shared_to, :organization_id, :google_language_id,
             :created_at, :updated_at, :published_at, :sensitive_data_state, :clear_sensitive_data_scheduled_at,
             :cat_mh_application_id, :cat_mh_organization_id, :cat_mh_pool, :created_cat_mh_session_count, :license_type, :is_access_revoked,
             :additional_text, :original_text, :quick_exit, :current_narrator, :live_chat_enabled, :hfhs_access, :warning_screen_enabled

  has_many :sessions, serializer: V1::SessionSerializer
  has_many :clinic_locations, serializer: V1::ClinicLocationSerializer

  cache_options(store: Rails.cache, namespace: 'intervention-serializer', expires_in: 24.hours) # temporary length, might be a subject to change

  attribute :starred do |object, params|
    object.starred_by?(params[:current_user_id])
  end

  attribute :files do |object|
    files_info(object) if object.files.attached?
  end

  attribute :first_session_language do |object|
    object.sessions&.first&.google_tts_voice&.google_tts_language&.language_name
  end

  attribute :csv do |object|
    if object.reports.attached?
      {
        generated_at: object.newest_report.created_at,
        filename: object.newest_report.blob.filename
      }
    end
  end

  attribute :language_name do |object|
    object.google_language.language_name
  end

  attribute :language_code do |object|
    object.google_language.language_code
  end

  attribute :exported_data do |object|
    if object.exported_data.attached?
      exported_data = object.exported_data
      {
        url: url_for(exported_data),
        generated_at: exported_data.blob.created_at.in_time_zone('UTC'),
        filename: exported_data.blob.filename
      }
    end
  end

  attribute :logo do |object|
    if object.logo.attached?
      {
        url: url_for(object.logo),
        alt: object.logo_blob.description
      }
    end
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
    if object.conversations_transcript.attached?
      blob = object.conversations_transcript.blob
      {
        generated_at: blob.created_at.in_time_zone('UTC'),
        filename: blob.filename
      }
    end
  end

  attribute :conversations_present do |object|
    object.conversations.size.positive?
  end

  def self.files_info(object)
    object.files.map do |file|
      map_file_data(file)
    end
  end

  def self.record_cache_options(options, fieldset, include_list, params)
    return super if params[:current_user_id].blank?

    options = options.dup
    options[:namespace] += ":#{params[:current_user_id]}"
    options
  end
end
