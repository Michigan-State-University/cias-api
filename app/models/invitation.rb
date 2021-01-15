# frozen_string_literal: true

class Invitation < ApplicationRecord
  belongs_to :invitable, polymorphic: true

  def resend
    return :unprocessable_entity unless invitable_type == 'Session' || invitable.published?

    SessionMailer.inform_to_an_email(invitable, email).deliver_later
    :ok
  end
end
