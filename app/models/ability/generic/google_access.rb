# frozen_string_literal: true

module Ability::Generic::GoogleAccess
  def enable_google_access
    can :read, GoogleLanguage
    can :read, GoogleTtsLanguage
    can :read, GoogleTtsVoice
  end
end
