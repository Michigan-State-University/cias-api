# frozen_string_literal: true

class V1::Interventions::Invitations::Show < BaseSerializer
  def cache_key
    "interventions/invitation/#{@user_session.id}-#{@user_session.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @user_session.id,
      email: @user_session.email
    }
  end
end
