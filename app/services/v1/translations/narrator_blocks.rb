# frozen_string_literal: true

class V1::Translations::NarratorBlocks
  attr_accessor :question, :narrator_blocks, :translator
  attr_reader :source_language_name_short, :destination_language_name_short

  def self.call(question, translator, source_language_name_short, destination_language_name_short)
    new(question, translator, source_language_name_short, destination_language_name_short).call
  end

  def initialize(question, translator, source_language_name_short, destination_language_name_short)
    @question = question
    @narrator_blocks = question.narrator['blocks']
    @translator = translator
    @source_language_name_short = source_language_name_short
    @destination_language_name_short = destination_language_name_short
  end

  def call
    narrator_blocks.each do |block|
      block['original_text'] = block['text']
      block['text'] = translate_text(block['text'], translator)
    end

    question.save!
  end

  private

  def translate_text(texts, translator)
    texts&.map do |text|
      variable?(text) ? text : translator.translate(text, source_language_name_short, destination_language_name_short)
    end
  end

  def variable?(text)
    /:[a-zA-Z0-9_]+:./.match(text).present?
  end
end
