# frozen_string_literal: true

class Question::Narrator::Standarize < SimpleDelegator
  def initialize(question)
    super(question)
  end

  def execute
    standarize_blocks
    standarize_from_question
    self
  end

  private

  def standarize_blocks
    narrator['blocks'].reject!(&:empty?)
    narrator['blocks'].each do |block|
      standarize_block(block) if block['type'].eql?('Speech')
      standarize_reflections(block) if block['type'].eql?('Reflection')
    end
  end

  def standarize_from_question
    narrator['from_question'][0]['text'].reject!(&:empty?)
    narrator['from_question'][0]['sha256'].reject!(&:empty?)
    narrator['from_question'][0]['audio_urls'].reject!(&:empty?)
  end

  def standarize_reflections(block)
    block['reflections'].reject!(&:empty?)
    block['reflections'].each do |reflection|
      standarize_block(reflection)
    end
  end

  def standarize_block(reflection)
    reflection['text'].reject!(&:empty?)
    reflection['sha256'].reject!(&:empty?)
    reflection['audio_urls'].reject!(&:empty?)
  end
end
