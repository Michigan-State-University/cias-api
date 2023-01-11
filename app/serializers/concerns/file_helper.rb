# frozen_string_literal: true

module FileHelper
  extend ActiveSupport::Concern

  class_methods do
    def map_file_data(file_data, timestamp_timezone = 'UTC')
      {
        id: file_data.id,
        name: file_data.blob.filename,
        url: ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(file_data, only_path: true),
        created_at: file_data.blob.created_at.in_time_zone(timestamp_timezone)
      }
    end
  end
end
