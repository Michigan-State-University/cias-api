# frozen_string_literal: true

class Ability::Guest < Ability::Base
  def definition
    super
    guest if role?(class_name)
  end

  private

  def guest
    can :read, Problem, allow_guests: true, status: 'published'
    can :read, Intervention, allow_guests: true, problem: { status: 'published' }
    can :read, Question, intervention: { allow_guests: true, problem: { status: 'published' } }
    can :create, Answer, question: { intervention: { allow_guests: true, problem: { status: 'published' } } }
  end
end
