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

  def standarize_from_question
    narrator['from_question'][0]['text'].reject!(&:empty?)
    narrator['from_question'][0]['sha256'].reject!(&:empty?)
    narrator['from_question'][0]['audio_urls'].reject!(&:empty?)
  end

  def standarize_blocks
    narrator['blocks'].reject!(&:empty?)
    narrator['blocks'].each do |block|
      next unless block['type'].eql?('Speech')

      block['text'].reject!(&:empty?)
      block['sha256'].reject!(&:empty?)
      block['audio_urls'].reject!(&:empty?)
    end
  end
end
