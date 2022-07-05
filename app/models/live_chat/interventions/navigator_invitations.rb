# frozen_string_literal: true

class LiveChat::Interventions::NavigatorInvitations < ApplicationRecord
  belongs_to :intervention

  encrypts :email
  blind_index :email

  scope :not_accepted, ->(intervention_id) { where(intervention_id: intervention_id, accepted_at: nil) }
end
