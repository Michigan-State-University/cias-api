# frozen_string_literal: true

class V1::Teams::Destroy
  def self.call(team)
    new(team).call
  end

  def initialize(team)
    @team = team
  end

  def call
    ActiveRecord::Base.transaction do
      team_admin&.update!(roles: ['researcher'])

      team.destroy!
    end
  end

  private

  attr_reader :team

  def team_admin
    team.team_admin
  end
end
