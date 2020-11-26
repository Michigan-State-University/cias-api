# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :read, Problem, Problem.available_for_participant(user.id)
    can :read, Session, problem_id: Problem.available_for_participant(user.id)
    can :read, QuestionGroup, session: { problem_id: Problem.available_for_participant(user.id) }
    can :read, Question, question_group: { session: { problem_id: Problem.available_for_participant(user.id) } }
    can :manage, Answer, question: { question_group: { session: { problem_id: Problem.available_for_participant(user.id) } } }
  end
end
