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
    is_image = blob.content_type.start_with?('image/')
    encoded_file = download_and_encode_file(blob, is_image)
    if encoded_file.present?
      {
        extension: blob.filename.extension,
        content_type: blob.content_type,
        description: blob.description,
        file: encoded_file,
        compressed: is_image
      }
    else
      {}
    end
  end

  def export_files(files)
    return [] unless files.attached?

    files.map do |file|
      blob = file.blob
      is_image = blob.content_type.start_with?('image/')
      encoded_file = download_and_encode_file(blob, is_image)
      next if encoded_file.blank?

      {
        extension: blob.filename.extension,
        content_type: blob.content_type,
        description: blob.description,
        file: encoded_file,
        metadata: file.metadata,
        compressed: is_image
      }
    end
  end

  def download_and_encode_file(blob, is_image)
    if is_image
      data = blob.download
      compressed = Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
      Base64.encode64(compressed)
    else
      Base64.encode64(blob.download)
    end
  rescue StandardError
    nil
  end
end
