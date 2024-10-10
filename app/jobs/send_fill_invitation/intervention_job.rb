# frozen_string_literal: true

class SendFillInvitation::InterventionJob < ApplicationJob
  def perform(intervention_id, existing_users_emails, non_existing_users_emails, health_clinic_id = nil)
    intervention = Intervention.find(intervention_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    User.where(email: existing_users_emails).find_each do |user|
      next unless user.email_notification

      InterventionMailer.with(locale: intervention.language_code).inform_to_an_email(intervention, user.email, health_clinic).deliver_now
    end

    non_existing_users_emails.each do |email|
      if intervention.shared_to_anyone?
        InterventionMailer.with(locale: intervention.language_code).inform_to_an_email(intervention, email, health_clinic).deliver_now
      else
        InterventionMailer.with(locale: intervention.language_code).invite_to_intervention_and_registration(intervention, email, health_clinic).deliver_now
      end
    end
  end
end
