# frozen_string_literal: true

class V1::Users::Show < BaseSerializer
  def cache_key
    "user/#{@user.id}-#{@user.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @user.id,
      email: @user.email,
      full_name: @user.full_name,
      first_name: @user.first_name,
      last_name: @user.last_name,
      phone: @user.phone,
      time_zone: @user.time_zone,
      active: @user.active,
      roles: @user.roles,
      team_id: @user.team_id,
      team_name: @user.team_name,
      avatar_url: url_for_image(@user, :avatar)
    }
  end
end
