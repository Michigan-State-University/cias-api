# frozen_string_literal: true

class Ability::EInterventionAdmin < Ability::Base
  def definition
    super
    e_intervention_admin if role?(class_name)
  end

  private

  def e_intervention_admin
    can %i[update active], User, id: participants_with_answers(user)
    can %i[read list_researchers], User, id: participants_and_researchers(user)
    can :create, :preview_session_user
    can :manage, Intervention, user_id: user.id
    can :manage, Intervention, id: Intervention.with_any_organization.where(organization_id: user.organizable_id)
    can :manage, UserSession, session: { intervention: { user_id: user.id } }
    can :manage, Session, intervention: { user_id: user.id }
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
    can :manage, Organization, e_intervention_admins: { id: user.id }
    can :invite_organization_admin, Organization, e_intervention_admins: { id: user.id }
    can :manage, HealthSystem, organization: { e_intervention_admins: { id: user.id } }
    can :invite_health_system_admin, HealthSystem, organization: { e_intervention_admins: { id: user.id } }
    can :manage, HealthClinic, health_system: { organization: { e_intervention_admins: { id: user.id } } }
    can :invite_health_clinic_admin, HealthClinic,
        health_system: { organization: { e_intervention_admins: { id: user.id } } }
    can :manage, ReportingDashboard, organization: { e_intervention_admins: { id: user.id } }
    can :manage, DashboardSection, reporting_dashboard: { organization: { e_intervention_admins: { id: user.id } } }
    can :manage, Chart,
        dashboard_section: { reporting_dashboard: { organization: { e_intervention_admins: { id: user.id } } } }
  end
end
