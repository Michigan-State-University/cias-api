# frozen_string_literal: true

class Ability::Researcher < Ability::Base
  def definition
    super
    researcher if role?(class_name)
  end

  private

  def researcher
    can :read, User, User.limit_to_roles(User::APP_ROLES[..-2]), deactivated: false
    can :manage, Problem, user_id: user.id
    can :manage, Intervention, user_id: user.id
    can :manage, Question, intervention: { user_id: user.id }
    can :manage, Answer, question: { intervention: { user_id: user.id } }
  end
end
