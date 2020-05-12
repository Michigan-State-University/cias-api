# frozen_string_literal: true

class Ability::GroupCoder < Ability::Base
  def definition
    super
    group_coder if role?(class_name)
  end

  private

  def group_coder; end
end
