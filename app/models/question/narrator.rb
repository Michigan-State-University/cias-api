# frozen_string_literal: true

class Question::Narrator
  include BlockHelper

  attr_accessor :question, :outdated_files, :speech_source

  def initialize(question)
    @question = question
  end

  def execute
    self.outdated_files = Blobs.new(question.narrator_was).execute

    return unless Launch.new(question, outdated_files).execute

    self.question = Standarize.new(question).execute
    self.speech_source = SpeechSource.new(question.narrator).execute
    blocks_processing
    outdated_files.purification
    question.save!
  end

  private

  def blocks_processing
    question.narrator['blocks'].each_with_index do |block, index|
      if speech?(block)
        processing(block, index)
      elsif reflection?(block)
        reflection_processing(block, index)
      end
    end
  end

  def processing(block, index_processing)
    old_block = question.narrator_was[speech_source][index_processing]
    speech = Block::Speech.new(self, index_processing, block, old_block).build
    question.narrator[speech_source][index_processing] = speech
  end

  def reflection_processing(block, index_processing)
    reflection = Block::Reflection.new(self, index_processing, block).build
    question.narrator[speech_source][index_processing] = reflection
  end
end
