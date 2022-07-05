# frozen_string_literal: true

class Navigators::InvitationJob < ApplicationJob
  def perform(email, intervention_id)
    user = User.find_by(email: email)
    intervention = Intervention.find(intervention_id)

    #   InterventionMailer.inform_to_an_email(
    #     intervention,
    #     user.email,
    #     health_clinic
    #   ).deliver_now
  end
end
