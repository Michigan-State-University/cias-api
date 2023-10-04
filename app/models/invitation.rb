# frozen_string_literal: true

class Invitation < ApplicationRecord
  has_paper_trail skip: %i[email migrated_email]
  belongs_to :invitable, polymorphic: true
  belongs_to :health_clinic, optional: true

  encrypts :email
  blind_index :email

  def resend
    invited_user = User.find_by(email: email)
    return :ok unless invited_user.nil? || invited_user.email_notification
    return :unprocessable_entity unless invitable.published?

    if invitable.is_a?(Session)
      scheduled_at = UserSession.find_by(user_id: invited_user&.id, session_id: invitable.id, health_clinic: health_clinic, finished_at: nil)&.scheduled_at
      SessionMailer.with(locale: invitable.language_code).inform_to_an_email(invitable, email, health_clinic, scheduled_at).deliver_later
    else
      InterventionMailer.with(locale: invitable.language_code).inform_to_an_email(invitable, email, health_clinic).deliver_later
    end
    :ok
  end
end
