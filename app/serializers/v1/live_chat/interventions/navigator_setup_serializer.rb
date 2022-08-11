# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorSetupSerializer < V1Serializer
  include FileHelper
  attributes :id, :notify_by, :contact_email, :no_navigator_available_message, :is_navigator_notification_on

  has_many :participant_links, serializer: V1::LiveChat::Interventions::LinkSerializer
  has_many :navigator_links, serializer: V1::LiveChat::Interventions::LinkSerializer
  has_one :phone, serializer: V1::PhoneSerializer

  attribute :participant_files do |object|
    (object.participant_files || []).map do |file_data|
      map_file_data(file_data)
    end
  end

  attribute :navigator_files do |object|
    (object.navigator_files || []).map do |file_data|
      map_file_data(file_data)
    end
  end
end
