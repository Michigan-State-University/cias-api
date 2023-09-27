# frozen_string_literal: true

class V1::Teams::Invitations::Create
  def self.call(team, user, roles)
    new(team, user, roles).call
  end

  def initialize(team, user, roles)
    @team = team
    @user = user
    @roles = roles
  end

  def call
    return if invitation_already_exists?
    return unless user.confirmed?
    return unless assign_roles!

    invitation = TeamInvitation.create!(
      user_id: user.id,
      team_id: team.id
    )

    TeamMailer.invite_user(
      invitation_token: invitation.invitation_token,
      email: user.email,
      team: team,
      roles: roles
    ).deliver_later # TODO: locale
  end

  private

  attr_reader :team, :user, :roles

  def invitation_already_exists?
    TeamInvitation.not_accepted.exists?(user_id: user.id, team_id: team.id)
  end

  def assign_roles!
    new_roles = user.roles + roles

    user.update(roles: new_roles.uniq)
  end
end
