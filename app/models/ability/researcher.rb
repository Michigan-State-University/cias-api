# frozen_string_literal: true

class Ability::Researcher < Ability::Base
  def definition
    super
    researcher if role?(class_name)
  end

  private

  def researcher
    can :read, User, deactivated: false
    can %i[read create], Intervention, user_id: user.id
    can %i[read create], Question, intervention: { user_id: user.id }
  end
end
