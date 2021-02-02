# frozen_string_literal: true

class V1::Teams::Create
  def self.call(team_params)
    new(team_params).call
  end

  def initialize(team_params)
    @team_params = team_params
  end

  def call
    ActiveRecord::Base.transaction do
      team = Team.create!(name: team_params[:name])

      researcher.update!(
        team_id: team.id,
        roles: ['team_admin']
      )

      team
    end
  end

  private

  attr_reader :team_params

  def researcher
    @researcher ||= User.researchers.find(team_params[:user_id])
  end
end
