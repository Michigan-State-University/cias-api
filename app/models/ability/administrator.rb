# frozen_string_literal: true

class Ability::Administrator < Ability::Base
  def definition
    super
    administrator if role?('administrator')
  end

  private

  def administrator
    can :manage, :all
  end
end
