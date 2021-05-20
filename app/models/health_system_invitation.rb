# frozen_string_literal: true

class HealthSystemInvitation < ApplicationRecord
  has_paper_trail
  belongs_to :user
  belongs_to :health_system

  has_secure_token :invitation_token
  validate :unique_invitation, on: :create

  scope :not_accepted, -> { where(accepted_at: nil) }

  private

  def unique_invitation
    return unless HealthSystemInvitation.not_accepted.exists?(user_id: user_id, health_system_id: health_system_id)

    errors.add(:user_id, :already_exists)
  end
end
