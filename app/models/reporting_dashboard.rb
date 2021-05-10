# frozen_string_literal: true

class ReportingDashboard < ApplicationRecord
  belongs_to :organization
  has_many :dashboard_sections
end
