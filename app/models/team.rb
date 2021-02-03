# frozen_string_literal: true

class Team < ApplicationRecord
  has_many :users, dependent: :nullify
  has_one :team_admin, -> { team_admins },
          inverse_of: :team, dependent: :nullify, class_name: 'User'

  validates :name, presence: true, uniqueness: true
end
