# frozen_string_literal: true

class Ability::EInterventionAdmin < Ability::Base
  def definition
    super
    e_intervention_admin if role?(class_name)
  end

  private

  def e_intervention_admin
    can %i[update active], User, id: participants_with_answers(user)
    can %i[read list_researchers], User, id: participants_researchers_and_e_intervention_admins(user)
    can %i[read update], User, id: users_in_organization(user)
    can :create, :preview_session_user
    can :manage, Intervention, user_id: user.id
    can :manage, Intervention, id: Intervention.with_any_organization.where(organization_id: user.organizable_id)
    can :manage, UserSession, session: { intervention: { user_id: user.id } }
    can :manage, Session, intervention: { user_id: user.id }
    can :read_cat_resources, User
    can :manage, Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability)
    can :manage, Invitation, invitable_type: 'Intervention', invitable_id: Intervention.accessible_by(ability)
    can :manage, QuestionGroup, session: { intervention: { user_id: user.id } }
    can :manage, Question, question_group: { session: { intervention: { user_id: user.id } } }
    can :manage, Answer, question: { question_group: { session: { intervention: { user_id: user.id } } } }
    can :manage, ReportTemplate, session: { intervention: { user_id: user.id } }
    can :manage, ReportTemplate::Section,
        report_template: { session: { intervention: { user_id: user.id } } }
    can :manage, ReportTemplate::Section::Variant,
        report_template_section: {
          report_template: { session: { intervention: { user_id: user.id } } }
        }
    can :manage, SmsPlan, session_id: logged_user_sessions(user)
    can :manage, SmsPlan::Variant, sms_plan: { session_id: logged_user_sessions(user) }
    can %i[read get_protected_attachment], GeneratedReport,
        user_session: { session: { intervention: { user_id: user.id } } }
    can :read, GoogleTtsLanguage
    can :read, GoogleTtsVoice
    can :read, GoogleLanguage
    can %i[read update], Organization, id: user.accepted_organization_ids
    can :invite_organization_admin, Organization, id: user.accepted_organization_ids
    can :manage, HealthSystem, organization: { id: user.organizable_id }
    can :invite_health_system_admin, HealthSystem, organization: { id: user.organizable_id }
    can :manage, HealthClinic, health_system: { organization: { id: user.organizable_id } }
    can :invite_health_clinic_admin, HealthClinic, health_system: { organization: { id: user.organizable_id } }
    can :manage, ReportingDashboard, organization: { id: user.organizable_id }
    can :manage, DashboardSection, reporting_dashboard: { organization: { id: user.organizable_id } }
    can :manage, Chart, dashboard_section: { reporting_dashboard: { organization: { id: user.organizable_id } } }
    can :read, ChartStatistic, chart: { dashboard_section: { reporting_dashboard: { organization: { id: user.organizable_id } } } }
    can :get_user_answers, Answer, user_session: { session: { intervention: { user_id: user.id } } }
  end

  def users_in_organization(user)
    organizations = user.organizations.joins(:health_systems, :health_clinics)
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
