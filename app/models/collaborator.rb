# frozen_string_literal: true

class Collaborator < ApplicationRecord
  has_paper_trail
  belongs_to :intervention
  belongs_to :user
end
