# frozen_string_literal: true

class Ability::HealthSystemAdmin < Ability::Base
  def definition
    super
    health_system_admin if role?(class_name)
  end

  private

  def health_system_admin
    can :read, Organization, health_systems: { health_system_admins: { id: user.id } }
    can :read, DashboardSection, reporting_dashboard: { organization: { health_systems: { health_system_admins: { id: user.id } } } }
    can :read, HealthSystem, health_system_admins: { id: user.id }
    can :read, ReportingDashboard, organization: { health_systems: { health_system_admins: { id: user.id } } }
    can :read, Chart,
        dashboard_section: { reporting_dashboard: { organization: { health_systems: { health_system_admins: { id: user.id } } } } }
    can :read, ChartStatistic, chart: { dashboard_section: { reporting_dashboard: { organization: { health_systems: { health_system_admins: { id: user.id } } } } } }
  end
end
