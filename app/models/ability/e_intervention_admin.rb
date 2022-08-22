# frozen_string_literal: true

class Ability::EInterventionAdmin < Ability::Researcher
  def definition
    super
    e_intervention_admin if role?(class_name)
  end

  private

  def e_intervention_admin
    can %i[read list_researchers], User, id: participants_and_researchers(user)
    can %i[read update], User, id: users_in_organization(user)
    can :manage, Intervention, id: Intervention.with_any_organization.where(organization_id: user.accepted_organization_ids)
    can :manage, UserSession, session: { intervention: { user_id: user.id } }
    can :manage, UserIntervention, intervention: { user_id: user.id }
    can %i[read update], Organization, id: user.accepted_organization_ids
    can :invite_organization_admin, Organization, id: user.accepted_organization_ids
    can :manage, HealthSystem, organization: { id: user.accepted_organization_ids }
    can :invite_health_system_admin, HealthSystem, organization: { id: user.accepted_organization_ids }
    can :manage, HealthClinic, health_system: { organization: { id: user.accepted_organization_ids } }
    can :invite_health_clinic_admin, HealthClinic, health_system: { organization: { id: user.accepted_organization_ids } }
    can :manage, ReportingDashboard, organization: { id: user.accepted_organization_ids }
    can :manage, DashboardSection, reporting_dashboard: { organization: { id: user.accepted_organization_ids } }
    can :manage, Chart, dashboard_section: { reporting_dashboard: { organization: { id: user.accepted_organization_ids } } }
    can :read, ChartStatistic, organization_id: user.accepted_organization_ids
  end

  def users_in_organization(user)
    organizations = user.accepted_organization.joins(:health_systems, :health_clinics)
    return [] if organizations.blank?

    organization_ids = organizations.pluck(:id)
    health_clinic_ids = organizations.pluck('health_clinics.id')
    health_system_ids = organizations.pluck('health_systems.id')

    organization_and_health_system_admin_ids(health_system_ids,
                                             organization_ids) + health_clinic_admin_ids(health_clinic_ids) + e_intervention_admin_ids(organization_ids)
  end

  def organization_and_health_system_admin_ids(health_system_ids, organization_ids)
    User.where(organizable_id: health_system_ids + organization_ids).pluck(:id) if health_system_ids.present? || organization_ids.present?
  end

  def health_clinic_admin_ids(health_clinic_ids)
    UserHealthClinic.where(health_clinic_id: health_clinic_ids).pluck(:user_id) if health_clinic_ids.present?
  end

  def e_intervention_admin_ids(organization_ids)
    EInterventionAdminOrganization.where(organization_id: organization_ids).pluck(:user_id) if organization_ids.present?
  end
end
