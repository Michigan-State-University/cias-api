# frozen_string_literal: true

class V1::Teams::AddTeamAdmin
  def self.call(team, team_admin_id)
    new(team, team_admin_id).call
  end

  def initialize(team, team_admin_id)
    @team          = team
    @team_admin_id = team_admin_id
  end

  def call
    return if already_team_admin?

    ActiveRecord::Base.transaction do
      current_team_admin.update!(
        roles: ['researcher']
      )

      new_team_admin.update!(
        roles: ['team_admin'],
        team_id: team.id
      )
    end
  end

  private

  attr_reader :team, :team_admin_id

  def new_team_admin
    @new_team_admin ||= User.researchers.find(team_admin_id)
  end

  def current_team_admin
    @current_team_admin ||= team.team_admin
  end

  def already_team_admin?
    new_team_admin.id == current_team_admin.id
  end
end
