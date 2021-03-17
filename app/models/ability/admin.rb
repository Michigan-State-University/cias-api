# frozen_string_literal: true

class Ability::Admin < Ability::Base
  def definition
    super
    admin if role?(class_name)
  end

  private

  def admin
    can :manage, :all
    can :add_logo, Intervention
  end
end
