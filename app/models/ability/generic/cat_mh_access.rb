# frozen_string_literal: true

module Ability::Generic::CatMhAccess
  def enable_cat_mh_access
    can :read_cat_resources, User
  end
end
