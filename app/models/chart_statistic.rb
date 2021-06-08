# frozen_string_literal: true

class ChartStatistic < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :health_system
  belongs_to :health_clinic
  belongs_to :user
  belongs_to :chart
end
