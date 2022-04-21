# frozen_string_literal: true

class V1::Users::Avatars::Create
  def self.call(user, file)
    new(user, file).call
  end

  def initialize(user, file)
    @user = user
    @file = file
  end

  def call
    user.update!(avatar: file)
    user
  end

  private

  attr_reader :file
  attr_accessor :user
end
