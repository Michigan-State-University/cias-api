# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :read, Intervention, Intervention.available_for_participant(user.email)
    can :read, Session, intervention: Intervention.available_for_participant(user.email)
    can :read, QuestionGroup, session: { intervention: Intervention.available_for_participant(user.email) }
    can :read, Question, question_group: { session: { intervention: Intervention.available_for_participant(user.email) } }
    can :manage, Answer, question: { question_group: { session: { intervention: Intervention.available_for_participant(user.email) } } }
  end
end
