# frozen_string_literal: true

class SessionInvitation < ApplicationRecord
  belongs_to :session, inverse_of: :session_invitations

  validates :email, uniqueness: { scope: :session }

  def resend
    return :unprocessable_entity unless session.published?

    SessionMailer.inform_to_an_email(session, email, nil).deliver_later
    :ok
  end
end
