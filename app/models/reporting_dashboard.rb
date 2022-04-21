# frozen_string_literal: true

class ReportingDashboard < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  has_many :dashboard_sections, dependent: :destroy
  has_many :charts, through: :dashboard_sections
end
