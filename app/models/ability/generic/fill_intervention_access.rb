# frozen_string_literal: true

module Ability::Generic::FillInterventionAccess
  def enable_fill_in_access(user_id, intervention_path)
    can :create, UserSession, session: { intervention: intervention_path }
    can :create, UserIntervention, intervention: intervention_path
    can %i[read update], UserSession, user_id: user_id
    can :create, Answer, user_session: { user_id: user_id }
    can :create, UserIntervention, user_id: user_id, intervention: intervention_path
    can :read, UserIntervention, user_id: user_id
    can :manage, Tlfb::Day, user_session: { user_id: user_id }
    can :manage, Tlfb::Event, day: { user_session: { user_id: user_id } }
    can :manage, Tlfb::ConsumptionResult, day: { user_session: { user_id: user_id } }
  end
end
