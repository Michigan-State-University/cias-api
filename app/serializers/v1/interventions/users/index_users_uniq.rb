# frozen_string_literal: true

class V1::Interventions::Users::IndexUsersUniq < BaseSerializer
  def cache_key
    "interventions/index-users-uniq/#{user_interventions.count}-#{user_interventions.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { user_interventions: collect_user_interventions }
  end

  private

  attr_reader :user_interventions

  def collect_user_interventions
    user_interventions.joins(:user).select(:user_id).distinct.map do |user_inter|
      {
        user_id: user_inter.user_id,
        email: user_inter.user.email
      }
    end
  end
end
