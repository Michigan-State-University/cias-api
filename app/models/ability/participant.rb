# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :read, Intervention, Intervention.available_for_participant(user.id)
    can :read, Session, intervention_id: Intervention.available_for_participant(user.id)
    can :read, QuestionGroup, session: { intervention_id: Intervention.available_for_participant(user.id) }
    can :read, Question, question_group: { session: { intervention_id: Intervention.available_for_participant(user.id) } }
    can :manage, Answer, question: { question_group: { session: { intervention_id: Intervention.available_for_participant(user.id) } } }
  end
end
