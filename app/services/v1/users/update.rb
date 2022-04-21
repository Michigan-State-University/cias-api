# frozen_string_literal: true

class V1::Users::Update
  def self.call(user, user_params)
    new(user, user_params).call
  end

  def initialize(user, user_params)
    @user = user
    @user_params = user_params
  end

  def call
    user.update!(user_params)
    user
  end

  private

  attr_reader :user_params
  attr_accessor :user
end
