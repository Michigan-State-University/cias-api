# frozen_string_literal: true

class Ability::Researcher < Ability::Base
  def definition
    super
    researcher if role?(class_name)
  end

  private

  def researcher
    can :read, User, deactivated: false
    can :manage, Problem, user_id: user.id
    can :manage, Intervention, user_id: user.id
    can :manage, Question, intervention_id: { user_id: user.id }
    can :read, Answer, question_id: { intervention_id: { user_id: user.id } }
  end
end
