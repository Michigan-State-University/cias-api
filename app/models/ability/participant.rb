# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :read, Problem, Problem.available_for_participant(user.id)
    can :read, Intervention, problem_id: Problem.available_for_participant(user.id)
    can :read, QuestionGroup, intervention: { problem_id: Problem.available_for_participant(user.id) }
    can :read, Question, question_group: { intervention: { problem_id: Problem.available_for_participant(user.id) } }
    can :manage, Answer, question: { question_group: { intervention: { problem_id: Problem.available_for_participant(user.id) } } }
  end
end
