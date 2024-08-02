# frozen_string_literal: true

class V1::MultipleCharacters::Interventions::ChangeService
  AVAILABLE_NARRATORS = %w[peedy emmi crystal].freeze
  private_constant :AVAILABLE_NARRATORS

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
    return unless new_character.in?(AVAILABLE_NARRATORS)

    intervention.sessions.each { |session| V1::MultipleCharacters::Sessions::ChangeService.call(session.id, new_character, replacement_animations) }
    intervention.update!(current_narrator: new_character)
  end
end
