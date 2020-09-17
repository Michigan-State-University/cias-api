# frozen_string_literal: true

class InterventionInvitation < ApplicationRecord
  belongs_to :intervention, inverse_of: :intervention_invitations

  validates :email, uniqueness: { scope: :intervention }

  def resend
    return :unprocessable_entity unless intervention.published?

    InterventionMailer.inform_to_an_email(intervention, email).deliver_later
    :ok
  end
end
