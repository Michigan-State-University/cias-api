# frozen_string_literal: true

class Ability::HealthClinicAdmin < Ability::Base
  def definition
    super
    health_clinic_admin if role?(class_name)
  end

  private

  def health_clinic_admin
    can :read, ReportingDashboard, organization: { health_systems: { health_clinics: { health_clinic_admins: { id: user.id } } } }
    can :confirm_health_clinic_membership, HealthClinicInvitation, user_id: user.id
    can :read, Chart, dashboard_section: { reporting_dashboard: { organization: { health_systems: { health_clinics: { health_clinic_admins: { id: user.id } } } } } }
  end
end
