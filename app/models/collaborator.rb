# frozen_string_literal: true

class Collaborator < ApplicationRecord
  has_paper_trail
  belongs_to :intervention, touch: true
  belongs_to :user
end
