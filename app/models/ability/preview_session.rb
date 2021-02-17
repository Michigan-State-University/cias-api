# frozen_string_literal: true

class Ability::PreviewSession < Ability::Base
  def definition
    super
    preview_session if role?(class_name)
  end

  private

  def preview_session
    can :read, Intervention, id: intervention_id, status: 'draft'
    can :read, Session, id: user.preview_session_id, intervention: { status: 'draft' }
    can :read, QuestionGroup, session: { id: user.preview_session_id, intervention: { status: 'draft' } }
    can :read, Question, question_group: { session: { id: user.preview_session_id, intervention: { status: 'draft' } } }
    can :create, Answer, question: { question_group: { session: { id: user.preview_session_id, intervention: { status: 'draft' } } } }
  end

  def intervention_id
    Session.find(user.preview_session_id).intervention_id
  end
end
