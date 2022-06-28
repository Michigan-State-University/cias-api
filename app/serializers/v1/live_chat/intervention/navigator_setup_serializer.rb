# frozen_string_literal: true

class V1::LiveChat::Intervention::NavigatorSetupSerializer < V1Serializer
  attributes :id, :notify_by, :contact_email, :no_navigator_available_message, :is_navigator_notification_on

  has_many :participant_links, serializer: V1::LiveChat::Intervention::ParticipantLinkSerializer
  has_one :phone, serializer: V1::PhoneSerializer
end
