# frozen_string_literal: true

class V1::Teams::InviteResearcher
  def self.call(team, email)
    new(team, email).call
  end

  def initialize(team, email)
    @team  = team
    @email = email
  end

  def call
    return if already_in_the_team?
    return if user_is_not_researcher?

    if user.blank?
      User.invite!(email: email, roles: ['researcher'], team_id: team.id)
    else
      V1::Teams::Invitations::Create.call(team, user)
    end
  end

  private

  attr_reader :team, :email

  def already_in_the_team?
    team.users.exists?(email: email)
  end

  def user_is_not_researcher?
    user&.roles&.exclude?('researcher') && user&.roles&.exclude?('e_intervention_admin')
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
