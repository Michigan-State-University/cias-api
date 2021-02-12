# frozen_string_literal: true

class Ability
  include CanCan::Ability

  attr_reader :user

  def initialize(user)
    @user = user || User.new
    inject_authorization
  end

  private

  def inject_authorization
    user.roles.each do |role|
      "::Ability::#{role.classify}".
        safe_constantize.new(self).definition
    end
  end
end
