# frozen_string_literal: true

class Ability::Guest < Ability::Base
  include Ability::Generic::FillInterventionAccess

  def definition
    super
    guest if role?(class_name)
  end

  private

  def guest
    enable_fill_in_access(user.id, { status: 'published', shared_to: 'anyone' })
  end
end
