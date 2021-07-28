# frozen_string_literal: true

class V1::Organizations::DashboardSections::Destroy
  def self.call(reporting_dashboard)
    new(reporting_dashboard).call
  end

  def initialize(reporting_dashboard)
    @reporting_dashboard = reporting_dashboard
  end

  def call
    reporting_dashboard.destroy!
  end

  private

  attr_reader :reporting_dashboard
end
