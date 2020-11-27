# frozen_string_literal: true

class Ability::Guest < Ability::Base
  def definition
    super
    guest if role?(class_name)
  end

  private

  def guest
    can :read, Intervention, status: 'published', shared_to: 'anyone'
    can :read, Session, intervention: { status: 'published', shared_to: 'anyone' }
    can :read, QuestionGroup, session: { intervention: { status: 'published', shared_to: 'anyone' } }
    can :read, Question, question_group: { session: { intervention: { status: 'published', shared_to: 'anyone' } } }
    can :create, Answer, question: { question_group: { session: { intervention: { status: 'published', shared_to: 'anyone' } } } }
  end
end
