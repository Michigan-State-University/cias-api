# frozen_string_literal: true

class V1::Teams::Invite
  def self.call(team, email, roles)
    new(team, email, roles).call
  end

  def initialize(team, email, roles)
    @team  = team
    @email = email
    @roles = roles
  end

  def call
    return if already_in_the_team?
    return if user_has_not_correct_role?

    if user.blank?
      User.invite!(email: email, roles: roles, team_id: team.id)
    else
      V1::Teams::Invitations::Create.call(team, user, roles)
    end
  end

  private

  attr_reader :team, :email, :roles

  def already_in_the_team?
    team.users.exists?(email: email)
  end

  def user_has_not_correct_role?
    user&.roles&.exclude?('researcher') && user&.roles.exclude?('navigator')
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
