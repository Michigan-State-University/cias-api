# frozen_string_literal: true

class TeamInvitation < ApplicationRecord
  belongs_to :user
  belongs_to :team

  has_secure_token :invitation_token
  validate :unique_invitation, on: :create

  scope :not_accepted, -> { where(accepted_at: nil) }

  private

  def unique_invitation
    return unless TeamInvitation.not_accepted.exists?(user_id: user_id, team_id: team_id)

    errors.add(:user_id, :already_exists)
  end
end
