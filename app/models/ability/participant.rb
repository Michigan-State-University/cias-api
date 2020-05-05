# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?('participant')
  end

  private

  def participant; end
end
