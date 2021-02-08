# frozen_string_literal: true

class Ability::TeamAdmin < Ability::Base
  def definition
    super
    team_admin if role?(class_name)
  end

  private

  def team_admin
    can %i[read update invite_researcher], Team, id: user.team_id
    can :read, User, team_id: user.team_id
  end
end
