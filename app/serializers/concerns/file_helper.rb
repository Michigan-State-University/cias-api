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
    {
      extension: blob.filename.extension,
      content_type: blob.content_type,
      description: blob.description,
      file: Base64.encode64(blob.download)
    }
  end
end
