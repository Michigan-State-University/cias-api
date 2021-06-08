# frozen_string_literal: true

class Ability::HealthClinicAdmin < Ability::Base
  def definition
    super
    health_clinic_admin if role?(class_name)
  end

  private

  def health_clinic_admin
    can :read, Organization, health_systems: { health_clinics: { user_health_clinics: { user_id: user.id } } }
    can :read, HealthClinic, user_health_clinics: { user_id: user.id }
    can :read, ReportingDashboard, organization: { health_systems: { health_clinics: { user_health_clinics: { user_id: user.id } } } }
    can :read, Chart, dashboard_section: { reporting_dashboard: { organization: { health_systems: { health_clinics: { user_health_clinics: { user_id: user.id } } } } } }
    can :read, ChartStatistic, chart: { dashboard_section: { reporting_dashboard: { organization: { health_systems: { health_clinics: { user_health_clinics: { user_id: user.id } } } } } } }
  end
end
