# frozen_string_literal: true

class Navigators::InvitationJob < ApplicationJob
  def perform(emails, intervention_id)
    users = User.where(email: emails)
    intervention = Intervention.find(intervention_id)

    users.each do |user|
      LiveChat::NavigatorMailer.navigator_intervention_invitation(user.email, intervention).deliver_now
    end
  end
end
