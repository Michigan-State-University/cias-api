# frozen_string_literal: true

class OrganizationInvitation < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  has_secure_token :invitation_token
  validate :unique_invitation, on: :create

  scope :not_accepted, -> { where(accepted_at: nil) }

  private

  def unique_invitation
    return unless OrganizationInvitation.not_accepted.exists?(user_id: user_id, organization_id: organization_id)

    errors.add(:user_id, :already_exists)
  end
end
