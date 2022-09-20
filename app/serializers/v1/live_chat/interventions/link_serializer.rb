# frozen_string_literal: true

class V1::LiveChat::Interventions::LinkSerializer < V1Serializer
  attributes :id, :url, :display_name, :navigator_setup_id, :link_for
end
