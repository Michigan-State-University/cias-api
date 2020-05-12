# frozen_string_literal: true

class Ability::Administrator < Ability::Base
  def definition
    super
    administrator if role?(class_name)
  end

  private

  def administrator
    can :manage, :all
  end
end
