# frozen_string_literal: true

class V1::Organizations::DashboardSections::Destroy
  def self.call(reporting_dashboard)
    new(reporting_dashboard).call
  end

  def initialize(reporting_dashboard)
    @reporting_dashboard = reporting_dashboard
  end

  def call
    ActiveRecord::Base.transaction do
      reporting_dashboard.destroy!
    end
  end

  private

  attr_reader :reporting_dashboard
end
