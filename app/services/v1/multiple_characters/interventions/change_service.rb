# frozen_string_literal: true

class V1::MultipleCharacters::Interventions::ChangeService
  def initialize(intervention_id, new_character, replacement_animations)
    @intervention = Intervention.find(intervention_id)
    @new_character = new_character
    @replacement_animations = replacement_animations
  end

  attr_accessor :intervention
  attr_reader :new_character, :replacement_animations

  def self.call(intervention_id, new_character, missing_animations)
    new(intervention_id, new_character, missing_animations).call
  end

  def call
    intervention.sessions.each { |session| V1::MultipleCharacters::Sessions::ChangeService.call(session.id, new_character, replacement_animations) }
  end
end
