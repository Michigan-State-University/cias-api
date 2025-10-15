# frozen_string_literal: true

class LiveChat::Interventions::NavigatorInvitation < ApplicationRecord
  belongs_to :intervention

  audited except: %i[email email_ciphertext]
  has_encrypted :email
  blind_index :email

  scope :not_accepted, -> { where(accepted_at: nil) }
end
