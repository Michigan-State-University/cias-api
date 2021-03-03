# frozen_string_literal: true

class Ability::Guest < Ability::Base
  def definition
    super
    guest if role?(class_name)
  end

  private

  def guest
    can :create, UserSession, session: { intervention: { status: 'published', shared_to: 'anyone' } }
    can :read, UserSession, user_id: user.id
    can :create, Answer, user_session: { user_id: user.id }
  end
end
