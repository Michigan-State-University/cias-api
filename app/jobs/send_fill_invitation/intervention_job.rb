# frozen_string_literal: true

class SendFillInvitation::SessionJob < ApplicationJob
  def perform(intervention_id, existing_users_emails, non_existing_users_emails, health_clinic_id = nil)
    intervention = Intervention.find(intervention_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    existing_users_emails.each do |email|
      user = User.find_by(email: email)
      next if user && !user.email_notification

      InterventionMailer.inform_to_an_email(intervention, email, health_clinic).deliver_now
    end

    method_name = "invite_to_#{model_class.name.downcase}_and_registration"
    non_existing_users_emails.each do |email|
      InterventionMailer.invite_to_intervention_and_registration(intervention, email, health_clinic).deliver_now
    end
  end
end
