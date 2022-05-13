# frozen_string_literal: true

class V1::Teams::Update
  prepend Database::Transactional

  def self.call(team, team_params, current_ability)
    new(team, team_params, current_ability).call
  end

  def initialize(team, team_params, current_ability)
    @team            = team
    @team_params     = team_params
    @current_ability = current_ability
  end

  def call
    team.update!(name: team_params[:name]) if name_changed?

    V1::Teams::ChangeTeamAdmin.call(
      team,
      team_params[:user_id],
      current_ability
    )

    team.reload
  end

  private

  attr_reader :team, :team_params, :current_ability

  def name_changed?
    return false if team_params[:name].blank?

    team.name != team_params[:name]
  end
end
