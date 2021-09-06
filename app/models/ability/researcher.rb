# frozen_string_literal: true

class Ability::Researcher < Ability::Base
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
    can :get_user_answers, Answer, user_session: { session: { intervention: { user_id: user.id } } }
  end
end
