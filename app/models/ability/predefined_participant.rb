# frozen_string_literal: true

class Ability::PredefinedParticipant < Ability::Base
  include Ability::Generic::FillInterventionAccess

  def definition
    super
    predefined_participant if role?(class_name)
  end

  private

  def predefined_participant
    enable_fill_in_access(user.id, { status: 'published' })
    can %i[index create], LiveChat::Conversation
  end
end
