# frozen_string_literal: true

class V1::Teams::Invitations::Create
  def self.call(team, user)
    new(team, user).call
  end

  def initialize(team, user)
    @team = team
    @user = user
  end

  def call
    return if invitation_already_exists?
    return unless user.confirmed?

    invitation = TeamInvitation.create!(
      user_id: user.id,
      team_id: team.id
    )

    TeamMailer.invite_user(
      invitation_token: invitation.invitation_token,
      email: user.email,
      team: team
    ).deliver_later
  end

  private

  attr_reader :team, :user

  def invitation_already_exists?
    TeamInvitation.not_accepted.exists?(user_id: user.id, team_id: team.id)
  end
end
