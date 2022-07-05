# frozen_string_literal: true

class Navigators::InvitationJob < ApplicationJob
  def perform(emails, intervention_id)
    # users = User.where(email: emails)
    # intervention = Intervention.find(intervention_id)

    #  [CIAS30-2359]
  end
end
