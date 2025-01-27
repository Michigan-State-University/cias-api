# frozen_string_literal: true

class LiveChat::Interventions::NavigatorInvitation < ApplicationRecord
  belongs_to :intervention

  has_encrypted :email
  blind_index :email

  scope :not_accepted, -> { where(accepted_at: nil) }
end
