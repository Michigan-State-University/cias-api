# frozen_string_literal: true

class SessionInvitation < ApplicationRecord
  has_paper_trail
  belongs_to :session, inverse_of: :session_invitations

  validates :email, uniqueness: { scope: :session }

  def resend
    return :unprocessable_entity unless session.published?

    SessionMailer.inform_to_an_email(session, email).deliver_later
    :ok
  end
end
