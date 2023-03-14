# frozen_string_literal: true

class V1::LiveChat::Interventions::LiveChatSetupSerializer < V1Serializer
  include FileHelper
  attributes :id, :contact_email, :no_navigator_available_message

  has_many :participant_links, serializer: V1::LiveChat::Interventions::LinkSerializer
  has_one :phone, serializer: V1::PhoneSerializer
  has_one :message_phone, serializer: V1::PhoneSerializer

  attribute :participant_files do |object|
    (object.participant_files || []).map do |file_data|
      map_file_data(file_data)
    end
  end
end
