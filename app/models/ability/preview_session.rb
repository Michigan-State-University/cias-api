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
    can :manage, UserSession, session: { intervention_id: intervention_id, intervention: { status: 'draft' } }
    can :manage, UserIntervention, intervention: { id: intervention_id, status: 'draft' }
    can :create, Answer, user_session: { user_id: user.id }
    can :manage, Tlfb::Event, day: { user_session: { user_id: user.id } }
  end

  def intervention_id
    Session.find(user.preview_session_id).intervention_id
  end
end
