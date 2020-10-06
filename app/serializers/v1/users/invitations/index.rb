# frozen_string_literal: true

class V1::Users::Invitations::Index < BaseSerializer
  def cache_key
    "users/invitations/#{@users.count}-#{@users.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    {
      invitations: collect_invitations
    }
  end

  private

  def collect_invitations
    @users.map { |user| V1::Users::Invitations::Show.new(user: user).to_json }
  end
end
