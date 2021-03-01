# frozen_string_literal: true

class V1::UserService
  def initialize(current_user)
    @users = User.accessible_by(current_user.ability)
  end

  attr_reader :users

  def users_scope
    users
  end

  def user_load(id)
    users_scope.find(id)
  end
end
