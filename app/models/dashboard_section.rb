# frozen_string_literal: true

class DashboardSection < ApplicationRecord
  belongs_to :reporting_dashboard
  has_many :charts, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :reporting_dashboard }

  default_scope { order(:name) }
end
