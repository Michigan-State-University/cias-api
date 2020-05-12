# frozen_string_literal: true

class Ability::ResearchAssistant < Ability::Base
  def definition
    super
    research_assistant if role?(class_name)
  end

  private

  def research_assistant
    can %i[read create], Intervention, user_id: user.id
    can %i[read create], Question, intervention: { user_id: user.id }
  end
end
