# frozen_string_literal: true

class DashboardSection < ApplicationRecord
  has_paper_trail
  belongs_to :reporting_dashboard
  has_many :charts, dependent: :destroy

  attribute :position, :integer, default: 1

  validates :name, presence: true, uniqueness: { scope: :reporting_dashboard }

  default_scope { order(:position) }
end
