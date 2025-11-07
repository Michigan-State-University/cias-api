# frozen_string_literal: true

class V1::Teams::ChangeTeamAdmin
  def self.call(team, team_admin_id, current_ability = nil)
    new(team, team_admin_id, current_ability).call
  end

  def initialize(team, team_admin_id, current_ability)
    @team            = team
    @team_admin_id   = team_admin_id # new team_admin
    @current_ability = current_ability
  end

  def call
    return unless able_to_change_team_admin?
    return if admin_not_changed?

    ActiveRecord::Base.transaction do
      if current_admin_of_one_team?
        current_team_admin.roles.delete('team_admin')
        current_team_admin.update!(
          roles: current_team_admin.roles,
          team_id: team.id
        )
      end

      team.update!(team_admin_id: team_admin_id)

      new_team_admin.update!(
        roles: (new_team_admin.roles << 'team_admin').uniq,
        team_id: nil # to avoid problems when researcher of the team becomes team_admin for this team
      )

      V1::Teams::RemoveUsersActiveInvitations.call(new_team_admin)
    end
  end

  private

  attr_reader :team, :team_admin_id, :current_ability

  def able_to_change_team_admin?
    return false if current_ability.blank?

    current_ability.can?(:change_team_admin, team)
  end

  def admin_not_changed?
    return true if team_admin_id.blank?

    current_team_admin.id.to_s == team_admin_id.to_s
  end

  def new_team_admin
    @new_team_admin ||= User.limit_to_roles(%w[researcher])
      .find(team_admin_id)
  end

  def current_team_admin
    @current_team_admin ||= team.team_admin
  end

  def current_admin_of_one_team?
    current_team_admin.admins_teams.one?
  end
end
