# frozen_string_literal: true

class V1::Teams::Update
  def self.call(team, team_params)
    new(team, team_params).call
  end

  def initialize(team, team_params)
    @team        = team
    @team_params = team_params
  end

  def call
    ActiveRecord::Base.transaction do
      team.update!(name: team_params[:name]) if name_changed?

      V1::Teams::ChangeTeamAdmin.call(team, team_params[:user_id])

      team.reload
    end
  end

  private

  attr_reader :team, :team_params

  def name_changed?
    return false if team_params[:name].blank?

    team.name != team_params[:name]
  end
end
