# frozen_string_literal: true

class Navigators::InvitationJob < ApplicationJob
  def perform(email, intervention_id)
    # user = User.find_by(email: email)
    # intervention = Intervention.find(intervention_id)

    #  [CIAS30-2359]
  end
end
