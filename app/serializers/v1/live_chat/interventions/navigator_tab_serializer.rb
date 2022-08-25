# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorTabSerializer < V1Serializer
  include UserHelper

  attribute :sent_invitations do |object|
    (object.live_chat_navigator_invitations.not_accepted || []).map do |invitation|
      map_invitation(invitation)
    end
  end

  attribute :navigators_in_team do |object|
    (object.navigators_from_team || []).map do |navigator|
      map_navigator_data(navigator)
    end
  end

  attribute :navigators do |object|
    (object.navigators || []).map do |navigator|
      map_navigator_data(navigator)
    end
  end
end
