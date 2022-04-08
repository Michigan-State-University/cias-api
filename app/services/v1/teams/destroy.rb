# frozen_string_literal: true

class V1::Teams::Destroy
  prepend Database::Transactional

  def self.call(team)
    new(team).call
  end

  def initialize(team)
    @team = team
  end

  def call
    team_admin&.update!(roles: ['researcher']) if last_team?

    team.destroy!
  end

  private

  attr_reader :team

  def team_admin
    team.team_admin
  end

  def last_team?
    team_admin.admins_teams.size == 1
  end
end
