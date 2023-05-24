# frozen_string_literal: true

module Ability::Generic::CollaboratorsAccess
  def enable_view_access(user)
    can :read, Intervention, collaborators: { user_id: user.id, view: true }
    can :read, Session, intervention: { collaborators: { user_id: user.id, view: true } }
    can :read, InterventionAccess, intervention: { collaborators: { user_id: user.id, view: true } }
    can :read, QuestionGroup, session: { intervention: { collaborators: { user_id: user.id, view: true } } }
    can :read, Question, question_group: { session: { intervention: { collaborators: { user_id: user.id, view: true } } } }
    can :read, ReportTemplate, session: { intervention: { collaborators: { user_id: user.id, view: true } } }
    can :read, ReportTemplate::Section, report_template: { session: { intervention: { collaborators: { user_id: user.id, view: true } } } }
    can :read, ReportTemplate::Section::Variant,
        report_template_section: { report_template: { session: { intervention: { collaborators: { user_id: user.id, view: true } } } } }
    can :read, SmsPlan, session: { intervention: { collaborators: { user_id: user.id, view: true } } }
    can :read, SmsPlan::Variant, sms_plan: { session: { intervention: { collaborators: { user_id: user.id, view: true } } } }
    can :read, Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability, :read)
    can :read, Invitation, invitable_type: 'Intervention', invitable_id: Intervention.accessible_by(ability, :read)
  end

  def enable_edit_access(user)
    can :manage, Intervention, collaborators: { user_id: user.id, edit: true }
    can :manage, Session, intervention: { collaborators: { user_id: user.id, edit: true } }
    can :manage, InterventionAccess, intervention: { collaborators: { user_id: user.id, edit: true } }
    can :manage, QuestionGroup, session: { intervention: { collaborators: { user_id: user.id, edit: true } } }
    can :manage, Question, question_group: { session: { intervention: { collaborators: { user_id: user.id, edit: true } } } }
    can :manage, ReportTemplate, session: { intervention: { collaborators: { user_id: user.id, edit: true } } }
    can :manage, ReportTemplate::Section, report_template: { session: { intervention: { collaborators: { user_id: user.id, edit: true } } } }
    can :manage, ReportTemplate::Section::Variant,
        report_template_section: { report_template: { session: { intervention: { collaborators: { user_id: user.id, edit: true } } } } }
    can :manage, SmsPlan::Variant, sms_plan: { session: { intervention: { collaborators: { user_id: user.id, edit: true } } } }
    can :manage, SmsPlan, session: { intervention: { collaborators: { user_id: user.id, edit: true } } }
  end

  def enable_data_access(user)
    can :manage, UserSession, session: { intervention: { collaborators: { user_id: user.id, data_access: true } } }
    can :read, UserIntervention, intervention: { collaborators: { user_id: user.id, data_access: true } }
    can %i[index create generate_transcript], LiveChat::Conversation, intervention: { collaborators: { user_id: user.id, data_access: true } }
    can :manage, Tlfb::ConsumptionResult, user_session: { session: { intervention: { collaborators: { user_id: user.id, data_access: true } } } }
    can :get_user_answers, Answer, user_session: { session: { intervention: { collaborators: { user_id: user.id, data_access: true } } } }
    can :create, DownloadedReport, generated_report: { user_session: { session: { intervention: { collaborators: { user_id: user.id, data_access: true } } } } }
    can %i[read get_protected_attachment], GeneratedReport,
        user_session: { session: { intervention: { collaborators: { user_id: user.id, data_access: true } } } }
    can :manage, Answer, question: { question_group: { session: { intervention: { collaborators: { user_id: user.id, data_access: true } } } } }
  end
end
