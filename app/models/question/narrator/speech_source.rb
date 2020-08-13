# frozen_string_literal: true

class Question::Narrator::SpeechSource
  attr_reader :narrator

  def initialize(narrator)
    @narrator = narrator
  end

  def execute
    narrator['blocks'].each do |block|
      return 'blocks' if block['type'].eql?('Speech') || block['type'].eql?('Reflection')
    end
    'from_question'
  end
end
