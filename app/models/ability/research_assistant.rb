# frozen_string_literal: true

class Ability::ResearchAssistant < Ability::Interface
  def definition
    super
    research_assistant if role?('research_assistant')
  end

  private

  def research_assistant; end
end
