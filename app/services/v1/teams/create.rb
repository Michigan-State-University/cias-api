# frozen_string_literal: true

class V1::Teams::Create
  prepend Database::Transactional

  def self.call(team_params)
    new(team_params).call
  end

  def initialize(team_params)
    @team_params = team_params
  end

  def call
    team = Team.create!(
      name: team_params[:name],
      team_admin_id: new_team_admin.id
    )

    new_team_admin.update!(
      roles: (new_team_admin.roles << 'team_admin').uniq
    )

    V1::Teams::RemoveUsersActiveInvitations.call(new_team_admin)

    team
  end

  private

  attr_reader :team_params

  def new_team_admin
    @new_team_admin ||= User.limit_to_roles(%w[researcher])
      .find(team_params[:user_id])
  end
end
