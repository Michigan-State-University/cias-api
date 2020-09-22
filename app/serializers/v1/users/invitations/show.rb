# frozen_string_literal: true

class V1::Users::Invitations::Show < BaseSerializer
  def cache_key
    "invitation/#{@user.id}-#{@user.updated_at}"
  end

  def to_json
    {
      id: @user.id,
      email: @user.email
    }
  end
end
