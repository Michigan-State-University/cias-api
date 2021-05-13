# frozen_string_literal: true

class ReportingDashboard < ApplicationRecord
  belongs_to :organization
  has_many :dashboard_sections
  has_many :charts, through: :dashboard_sections
end
