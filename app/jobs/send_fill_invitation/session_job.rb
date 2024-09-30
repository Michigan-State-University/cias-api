# frozen_string_literal: true

class SendFillInvitation::SessionJob < ApplicationJob
  def perform(session_id, existing_users_emails, non_existing_users_emails, health_clinic_id = nil, intervention_id = nil)
    session = Session.find(session_id)
    health_clinic = HealthClinic.find_by(id: health_clinic_id)

    User.where(email: existing_users_emails).find_each do |user|
      next unless user.email_notification

      user_intervention = UserIntervention.find_or_create_by(user_id: user.id, intervention_id: intervention_id, health_clinic_id: health_clinic_id)
      user_session = UserSession.find_by(session_id: session_id,
                                         user_id: user.id,
                                         health_clinic_id: health_clinic_id,
                                         type: session.user_session_type,
                                         user_intervention_id: user_intervention.id)
      SessionMailer.with(locale: session.language_code).inform_to_an_email(session, user.email, health_clinic, user_session&.scheduled_at).deliver_now
    end

    non_existing_users_emails.each do |email|
      if session.intervention.shared_to_anyone?
        SessionMailer.with(locale: session.language_code).inform_to_an_email(session, email, health_clinic).deliver_now
      else
        SessionMailer.with(locale: session.language_code).invite_to_session_and_registration(session, email, health_clinic).deliver_now
      end

    end
  end
end
