# frozen_string_literal: true

class SendFillInvitation::SessionJob < ApplicationJob
  def perform(session_id, existing_users_emails, non_existing_users_emails, health_clinic_id = nil, intervention_id = nil)
    session = Session.find(session_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    existing_users_emails.each do |email|
      user = User.find_by(email: email)
      next if user && !user.email_notification

      user_intervention = UserIntervention.find_or_create_by(user_id: user.id, intervention_id: intervention_id, health_clinic_id: health_clinic_id)
      user_session = UserSession.find_by(session_id: session_id,
                                         user_id: user.id,
                                         health_clinic_id: health_clinic_id,
                                         type: session.user_session_type,
                                         user_intervention_id: user_intervention.id)
      SessionMailer.inform_to_an_email(session, email, health_clinic, user_session&.scheduled_at).deliver_now
    end

    non_existing_users_emails.each do |email|
      SessionMailer.invite_to_session_and_registration(session, email, health_clinic).deliver_now
    end
  end
end
