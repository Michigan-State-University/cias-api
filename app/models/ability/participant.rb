# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant; end
end
