# frozen_string_literal: true

class V1::Users::Avatars::Destroy
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    user.avatar.purge
    user
  end

  private

  attr_accessor :user
end
