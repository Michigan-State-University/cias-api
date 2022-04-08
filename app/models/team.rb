# frozen_string_literal: true

class Team < ApplicationRecord
  has_paper_trail
  has_many :users, dependent: :nullify
  belongs_to :team_admin, class_name: 'User'
  has_many :team_invitations, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  default_scope { order(created_at: :desc) }

  scope :name_contains, ->(name) { where('name ilike ?', "%#{name}%") if name.present? }

  def self.detailed_search(params)
    scope = all

    scope.name_contains(params[:name])
  end
end
