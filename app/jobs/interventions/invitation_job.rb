# frozen_string_literal: true

class Interventions::InvitationJob < ApplicationJob
  def perform(intervention_id, emails, health_clinic_id = nil)
    users = User.where(email: emails)
    intervention = Intervention.find(intervention_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    users.each do |user|
      next unless user.email_notification

      InterventionMailer.inform_to_an_email(
        intervention,
        user.email,
        health_clinic
      ).deliver_now
    end
  end
end
