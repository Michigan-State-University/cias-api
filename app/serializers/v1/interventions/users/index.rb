# frozen_string_literal: true

class V1::Interventions::Users::Index < BaseSerializer
  def cache_key
    "interventions/users/#{@user_interventions.count}-#{@user_interventions.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { user_interventions: collect_user_interventions }
  end

  private

  def collect_user_interventions
    @user_interventions.map do |user_inter|
      V1::Interventions::Users::Show.new(user_intervention: user_inter).to_json
    end
  end
end
