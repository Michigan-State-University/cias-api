# frozen_string_literal: true

class V1::GeneratedTranscriptSerializer < V1Serializer
  include FileHelper

  attributes :id

  attribute :name do |object|
    object.blob.filename if object.present?
  end

  attribute :url do |object|
    ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(object, only_path: true) if object.present?
  end

  attribute :created_at do |object|
    object.blob.created_at.in_time_zone('UTC') if object.present?
  end
end
