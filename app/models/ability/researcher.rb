# frozen_string_literal: true

class Ability::Researcher < Ability::Base
  def definition
    super
    researcher if role?(class_name)
  end

  private

  def researcher
    can :read, User, User.limit_to_roles(roles_without_admin), active: true
    can :manage, Intervention, user_id: user.id
    can :manage, UserSession, session: { intervention: { user_id: user.id } }
    can :manage, Session, intervention: { user_id: user.id }
    can :manage, Invitation, invitable_type: 'Session', invitable_id: Session.accessible_by(ability)
    can :manage, Invitation, invitable_type: 'Intervention', invitable_id: Intervention.accessible_by(ability)
    can :manage, QuestionGroup, session: { intervention: { user_id: user.id } }
    can :manage, Question, question_group: { session: { intervention: { user_id: user.id } } }
    can :manage, Answer, question: { question_group: { session: { intervention: { user_id: user.id } } } }
    can :manage, ReportTemplate, session: { intervention: { user_id: user.id } }
  end

  def roles_without_admin
    @roles_without_admin ||= User::APP_ROLES - ['admin']
  end
end
