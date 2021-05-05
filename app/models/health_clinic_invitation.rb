# frozen_string_literal: true

class HealthClinicInvitation < ApplicationRecord
  belongs_to :user
  belongs_to :health_clinic

  has_secure_token :invitation_token
  validate :unique_invitation, on: :create

  scope :not_accepted, -> { where(accepted_at: nil) }

  private

  def unique_invitation
    return unless HealthClinicInvitation.not_accepted.exists?(user_id: user_id, health_clinic_id: health_clinic_id)

    errors.add(:user_id, :already_exists)
  end
end
