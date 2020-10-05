# frozen_string_literal: true

class V1::Users::Index < BaseSerializer
  def cache_key
    "users/#{@users.count}-#{@users.maximum(:updated_at)}"
  end

  def to_json
    {
      users_size: @users.size,
      users: collect_users
    }
  end

  private

  def collect_users
    @users.map { |user| V1::Users::Show.new(user: user).to_json }
  end
end
