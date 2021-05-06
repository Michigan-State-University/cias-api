# frozen_string_literal: true

class V1::Organizations::DashboardSections::Create
  def self.call(organization, dashboard_section_params)
    new(organization, dashboard_section_params).call
  end

  def initialize(organization, dashboard_section_params)
    @organization = organization
    @dashboard_section_params = dashboard_section_params
  end

  def call
    ActiveRecord::Base.transaction do
      dashboard_section = DashboardSection.create!(
        name: dashboard_section_params[:name],
        description: dashboard_section_params[:description],
        reporting_dashboard: @organization.reporting_dashboard
      )

      dashboard_section
    end
  end

  private

  attr_reader :organization, :dashboard_section_params
end
