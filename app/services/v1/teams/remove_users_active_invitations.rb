# frozen_string_literal: true

class V1::Teams::RemoveUsersActiveInvitations
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    TeamInvitation.not_accepted.where(user_id: user.id).destroy_all
  end

  private

  attr_reader :user
end
