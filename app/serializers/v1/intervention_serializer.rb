# frozen_string_literal: true

class V1::InterventionSerializer < V1Serializer
  attributes :name, :user_id, :sessions, :status, :shared_to, :organization_id, :google_language_id

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

  attributes :logo_url do |object|
    url_for(object.logo) if object.logo.attached?
  end

  attribute :image_alt do |object|
    object.logo_blob.description if object.logo_blob.present?
  end

  attribute :sessions_size do |object|
    object.sessions.size
  end

  def self.newest_csv_link(object)
    ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(object.newest_report, only_path: true)
  end
end
