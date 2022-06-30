# frozen_string_literal: true

class V1::LiveChat::Interventions::ParticipantLinkSerializer < V1Serializer
  attributes :id, :url, :display_name, :navigator_setup_id
end
