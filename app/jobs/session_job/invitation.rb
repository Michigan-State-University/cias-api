# frozen_string_literal: true

class SessionJob::Invitation < SessionJob
  def perform(session_id, emails, health_clinic_id)
    users = User.where(email: emails)
    session = Session.find(session_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    users.each do |user|
      next unless user.email_notification

      if health_clinic.nil?
        SessionMailer.inform_to_an_email(
          session,
          user.email
        ).deliver_now
      end

      next if health_clinic.blank?

      SessionMailer.inform_to_an_email_in_clinic(
        session,
        user.email,
        health_clinic
      ).deliver_now
    end
  end
end
