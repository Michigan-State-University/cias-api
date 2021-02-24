# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :create, UserSession, session: { intervention: Intervention.available_for_participant(user.email) }
    can :create, Answer, user_session: { user_id: user.id }
  end
end
