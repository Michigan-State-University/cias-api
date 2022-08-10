# frozen_string_literal: true

class V1::LiveChat::Interventions::LiveChatSetupSerializer < V1Serializer
  attributes :id, :contact_email, :no_navigator_available_message

  has_many :participant_links, serializer: V1::LiveChat::Interventions::LinkSerializer
  has_one :phone, serializer: V1::PhoneSerializer

  attribute :participant_files do |object|
    (object.participant_files || []).map do |file_data|
      {
        id: file_data.id,
        filename: file_data.blob.filename,
        url: ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(file_data, only_path: true)
      }
    end
  end
end
