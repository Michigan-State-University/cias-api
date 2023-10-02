# frozen_string_literal: true

class V1::LiveChat::Interventions::Navigators::Assign
  def self.call(user_id, intervention)
    new(user_id, intervention).call
  end

  def initialize(user_id, intervention)
    @user_id = user_id
    @intervention = intervention
  end

  def call
    navigator = intervention.navigators_from_team.find(user_id)
    intervention.navigators << navigator

    LiveChat::NavigatorMailer.navigator_from_team_invitation(navigator.email, intervention).deliver_now
    navigator
  end

  attr_accessor :user_id, :intervention
end
