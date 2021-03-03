# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :read, Intervention, Intervention.available_for_participant(user.email)
    can :read, Session, intervention_id: Intervention.available_for_participant(user.email)
    can :read, QuestionGroup, session: { intervention_id: Intervention.available_for_participant(user.email) }
    can :read, Question, question_group: { session: { intervention_id: Intervention.available_for_participant(user.email) } }
    can :manage, Answer, question: { question_group: { session: { intervention_id: Intervention.available_for_participant(user.email) } } }
    can :read, GeneratedReport, user_session: { user_id: user.id }, report_for: 'participant',
                                shown_for_participant: true
  end
end
