# frozen_string_literal: true

class Invitation < ApplicationRecord
  belongs_to :invitable, polymorphic: true

  encrypts :email, migrating: true
  blind_index :email, migrating: true

  def resend
    invited_user = User.find_by(email: email)
    return :ok unless invited_user.email_notification
    return :unprocessable_entity unless invitable_type == 'Session' || invitable.published?

    SessionMailer.inform_to_an_email(invitable, email).deliver_later
    :ok
  end
end
