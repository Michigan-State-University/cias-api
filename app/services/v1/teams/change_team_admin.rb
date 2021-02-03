# frozen_string_literal: true

class V1::Teams::ChangeTeamAdmin
  def self.call(team, team_admin_id)
    new(team, team_admin_id).call
  end

  def initialize(team, team_admin_id)
    @team          = team
    @team_admin_id = team_admin_id
  end

  def call
    return if admin_not_changed?

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

  def admin_not_changed?
    return true if team_admin_id.blank?

    current_team_admin.id.to_s == team_admin_id.to_s
  end
end
