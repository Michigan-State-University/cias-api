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
    can :manage, SessionInvitation, session: { intervention: { user_id: user.id } }
    can :manage, Session, intervention: { user_id: user.id }
    can :manage, QuestionGroup, session: { intervention: { user_id: user.id } }
    can :manage, Question, question_group: { session: { intervention: { user_id: user.id } } }
    can :manage, Answer, question: { question_group: { session: { user_id: user.id } } }
  end

  def roles_without_admin
    @roles_without_admin ||= User::APP_ROLES - ['admin']
  end
end
