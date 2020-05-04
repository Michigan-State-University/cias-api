# frozen_string_literal: true

class Ability::Administrator < Ability::Interface
  def definition
    super
    administrator if role?('administrator')
  end

  private

  def administrator; end
end
