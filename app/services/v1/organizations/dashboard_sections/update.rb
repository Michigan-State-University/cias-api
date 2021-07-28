# frozen_string_literal: true

class V1::Organizations::DashboardSections::Update
  def self.call(dashboard_section, dashboard_section_params)
    new(dashboard_section, dashboard_section_params).call
  end

  def initialize(dashboard_section, dashboard_section_params)
    @dashboard_section = dashboard_section
    @dashboard_section_params = dashboard_section_params
  end

  def call
    dashboard_section.name = dashboard_section_params[:name] if name_changed?
    dashboard_section.description = dashboard_section_params[:description] if description_changed?
    dashboard_section.save!

    dashboard_section.reload
  end

  private

  attr_reader :dashboard_section, :dashboard_section_params

  def name_changed?
    return false if dashboard_section_params[:name].blank?

    dashboard_section.name != dashboard_section_params[:name]
  end

  def description_changed?
    return false if dashboard_section_params[:description].blank?

    dashboard_section.description != dashboard_section_params[:description]
  end
end
