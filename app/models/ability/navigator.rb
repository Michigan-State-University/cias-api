# frozen_string_literal: true

class Ability::Navigator < Ability::Base
  def definition
    super
    navigator if role?(class_name)
  end

  private

  def navigator
    can %i[index generate_transcript], LiveChat::Conversation
    can :read, LiveChat::Interventions::NavigatorSetup, intervention: { navigators: { id: user.id } }
  end
end
