# frozen_string_literal: true

class SendFillInvitationJob < ApplicationJob
  def perform(model_class, object_id, existing_users_emails, non_existing_users_emails, health_clinic_id = nil)
    object = model_class.find(object_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    mailer_class = "#{model_class.name}Mailer".safe_constantize

    existing_users_emails.each do |email|
      user = User.find_by(email: email)
      next if user && !user.email_notification

      mailer_class.inform_to_an_email(object, email, health_clinic).deliver_now
    end

    method_name = "invite_to_#{model_class.name.downcase}_and_registration"
    non_existing_users_emails.each do |email|
      mailer_class.send(method_name, object, email, health_clinic).deliver_now
    end
  end
end
