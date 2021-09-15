# frozen_string_literal: true

class EInterventionAdminOrganization < ApplicationRecord
  has_paper_trail
  belongs_to :user
  belongs_to :organization
end
