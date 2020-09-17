# frozen_string_literal: true

class Ability::Researcher < Ability::Base
  def definition
    super
    researcher if role?(class_name)
  end

  private

  def researcher
    can :read, User, User.limit_to_roles(roles_without_admin), active: true
    can :manage, Problem, user_id: user.id
    can :manage, UserIntervention, intervention: { problem: { user_id: user.id } }
    can :manage, InterventionInvitation, intervention: { problem: { user_id: user.id } }
    can :manage, Intervention, problem: { user_id: user.id }
    can :manage, Question, intervention: { user_id: user.id }
    can :manage, Answer, question: { intervention: { user_id: user.id } }
  end

  def roles_without_admin
    @roles_without_admin ||= User::APP_ROLES - ['admin']
  end
end
