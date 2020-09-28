# frozen_string_literal: true

class V1::Users::Invitations::Update < BaseSerializer
  def cache_key
    "users/invitation/#{@user.id}-#{@user.updated_at}"
  end

  def to_json
    {
      id: @user.id,
      email: @user.email,
      full_name: @user.full_name,
      first_name: @user.first_name,
      last_name: @user.last_name,
      time_zone: @user.time_zone,
      active: @user.active
    }
  end
end
