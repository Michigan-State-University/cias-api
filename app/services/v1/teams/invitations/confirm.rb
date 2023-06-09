# frozen_string_literal: true

class V1::Teams::Invitations::Confirm
  prepend Database::Transactional

  def self.call(team_invitation)
    new(team_invitation).call
  end

  def initialize(team_invitation)
    @team            = team_invitation.team
    @user            = team_invitation.user
    @team_invitation = team_invitation
  end

  def call
    user.update!(team_id: team.id)

    team_invitation.update!(
      accepted_at: Time.current,
      invitation_token: nil
    )
  end

  private

  attr_reader :team, :user, :team_invitation
end
