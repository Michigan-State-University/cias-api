# frozen_string_literal: true

class V1::Users::Invitations::Update
  def self.call(accept_invitation_params)
    new(accept_invitation_params).call
  end

  def initialize(accept_invitation_params)
    @accept_invitation_params = accept_invitation_params
  end

  def call
    user = User.accept_invitation!(accept_invitation_params)
    user.activate!
    user
  end

  private

  attr_reader :accept_invitation_params
end
