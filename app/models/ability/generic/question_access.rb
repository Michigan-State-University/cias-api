# frozen_string_literal: true

module Ability::Generic::QuestionAccess
  def enable_questions_access(ids)
    can :manage, QuestionGroup, session: { intervention: { user_id: ids } }
    can :manage, Question, question_group: { session: { intervention: { user_id: ids } } }
    can :manage, Answer, question: { question_group: { session: { intervention: { user_id: ids } } } }
  end
end
