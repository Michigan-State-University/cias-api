# frozen_string_literal: true

class Ability::Participant < Ability::Interface
  def definition
    super
    participant if role?('participant')
  end

  private

  def participant; end
end
