# frozen_string_literal: true

class Ability::Researcher < Ability::Base
  include Ability::Generic::GoogleAccess
  include Ability::Generic::ReportTemplateAccess
  include Ability::Generic::SmsPlanAccess
  include Ability::Generic::QuestionAccess
  include Ability::Generic::CatMhAccess

  def definition
    super
    researcher if role?(class_name)
  end

  private

  def researcher
    can %i[update active], User, id: participants_with_answers(user)
    can %i[read list_researchers], User, id: participants_and_researchers(user)
    can :create, :preview_session_user
    can :manage, Intervention, user_id: user.id
    can :manage, UserSession, session: { intervention: { user_id: user.id } }
    can :read, UserIntervention, intervention: { user_id: user.id }
    can :manage, Session, intervention: { user_id: user.id }
    can :manage, Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability)
    can :manage, Invitation, invitable_type: 'Intervention', invitable_id: Intervention.accessible_by(ability)
    can :manage, InterventionAccess, intervention: { user_id: user.id }

    enable_questions_access(user.id)
    enable_report_template_access(user.id)
    enable_sms_plan_access(logged_user_sessions(user))
    enable_cat_mh_access

    can %i[read get_protected_attachment], GeneratedReport,
        user_session: { session: { intervention: { user_id: user.id } } }
    can :create, DownloadedReport, generated_report: { user_session: { session: { intervention: { user_id: user.id } } } }
    can :get_user_answers, Answer, user_session: { session: { intervention: { user_id: user.id } } }
    enable_google_access
  end
end
