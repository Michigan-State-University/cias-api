# frozen_string_literal: true

class Ability::Guest < Ability::Base
  def definition
    super
    guest if role?(class_name)
  end

  private

  def guest
    can :read, Problem, status: 'published', shared_to: 'anyone'
    can :read, Intervention, problem: { status: 'published', shared_to: 'anyone' }
    can :read, QuestionGroup, intervention: { problem: { status: 'published', shared_to: 'anyone' } }
    can :read, Question, question_group: { intervention: { problem: { status: 'published', shared_to: 'anyone' } } }
    can :create, Answer, question: { question_group: { intervention: { problem: { status: 'published', shared_to: 'anyone' } } } }
  end
end
