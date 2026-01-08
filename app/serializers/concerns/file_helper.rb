# frozen_string_literal: true

module FileHelper
  extend ActiveSupport::Concern

  class_methods do
    def map_file_data(file_data, timestamp_timezone = 'UTC')
      {
        id: file_data.id,
        name: file_data.blob.filename,
        url: ENV.fetch('APP_HOSTNAME', nil) + Rails.application.routes.url_helpers.rails_blob_path(file_data, only_path: true),
        created_at: file_data.blob.created_at.in_time_zone(timestamp_timezone)
      }
    end
  end

  def export_file(file)
    return unless file.attached?

    blob = file.blob
    encoded_file = download_and_encode_file(blob)
    if encoded_file.present?
      {
        extension: blob.filename.extension,
        content_type: blob.content_type,
        description: blob.description,
        file: encoded_file
      }
    else
      {}
    end
  end

  def export_files(files)
    return [] unless files.attached?

    files.map do |file|
      blob = file.blob
      encoded_file = download_and_encode_file(blob)
      next if encoded_file.blank?

      {
        extension: blob.filename.extension,
        content_type: blob.content_type,
        description: blob.description,
        file: encoded_file,
        metadata: file.metadata
      }
    end
  end

  def download_and_encode_file(blob)
    Base64.encode64(blob.download)
  rescue StandardError
    nil
  end
end
