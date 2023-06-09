# frozen_string_literal: true

class SessionJobs::Invitation < SessionJob
  def perform(session_id, existing_user_emails, non_existing_user_emails, health_clinic_id = nil)
    users = User.where(email: existing_user_emails)
    session = Session.find(session_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    users.each do |user|
      next unless user.email_notification

      SessionMailer.inform_to_an_email(
        session,
        user.email,
        health_clinic
      ).deliver_now
    end

    non_existing_user_emails.each do |email|
      SessionMailer.invite_to_session_and_registration(
        session,
        email,
        health_clinic
      ).deliver_now
    end
  end
end
