# frozen_string_literal: true

class V1::MultipleCharacters::Sessions::ChangeService
  AVAILABLE_NARRATORS = %w[peedy emmi].freeze
  private_constant :AVAILABLE_NARRATORS

  def initialize(session_id, new_character, replacement_animations)
    @session = Session.find(session_id)
    @new_character = new_character
    @replacement_animations = replacement_animations
  end

  attr_accessor :session
  attr_reader :new_character, :replacement_animations

  def self.call(session_id, new_character, missing_animations)
    new(session_id, new_character, missing_animations).call
  end

  def call
    return unless new_character.in?(AVAILABLE_NARRATORS)

    update_character_in_session_questions if session.is_a?(Session::Classic)

    session.update!(current_narrator: new_character)
  end

  private

  def update_character_in_session_questions
    session.questions.each do |question|
      next unless valid_change?(question)

      update_character(question)
      update_blocks(question) if replacement_animations.present?

      question.save!
    end
  end

  def update_character(question)
    question.narrator['settings']['character'] = new_character
  end

  def valid_change?(question)
    question.narrator['settings']['character'] == session.current_narrator
  end

  def update_blocks(question)
    question.narrator['blocks'].each do |block|
      new_animation = replacement_animations[block['animation']]
      block['animation'] = new_animation if new_animation.present?
    end
  end
end
