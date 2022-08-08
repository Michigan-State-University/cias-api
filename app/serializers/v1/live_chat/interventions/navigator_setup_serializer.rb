# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorSetupSerializer < V1Serializer
  attributes :id, :notify_by, :contact_email, :no_navigator_available_message, :is_navigator_notification_on

  has_many :participant_links, serializer: V1::LiveChat::Interventions::LinkSerializer
  has_many :navigator_links, serializer: V1::LiveChat::Interventions::LinkSerializer
  has_one :phone, serializer: V1::PhoneSerializer

  attribute :participant_files do |object|
    (object.participant_files || []).map do |file_data|
      {
        id: file_data.id,
        name: file_data.blob.filename,
        url: ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(file_data, only_path: true)
      }
    end
  end
end
