# frozen_string_literal: true

class V1::Users::Invitations::Create
  def self.call(invited_email)
    new(invited_email).call
  end

  def initialize(invited_email)
    @invited_email = invited_email
  end

  def call
    return if User.exists?(email: invited_email)

    User.invite!(email: invited_email, roles: %w[researcher])
  end

  private

  attr_reader :invited_email
end
