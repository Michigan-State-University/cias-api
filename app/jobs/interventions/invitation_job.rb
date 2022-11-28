# frozen_string_literal: true

class Interventions::InvitationJob < ApplicationJob
  def perform(intervention_id, existing_user_emails, non_existing_user_emails, health_clinic_id = nil)
    users = User.where(email: existing_user_emails)
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

    non_existing_user_emails.each do |email|
      InterventionMailer.invite_to_intervention_and_registration(
        intervention,
        email,
        health_clinic
      ).deliver_now
    end
  end
end
