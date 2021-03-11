# frozen_string_literal: true

class Question::Narrator
  include BlockHelper

  attr_accessor :question, :outdated_files

  def initialize(question)
    @question = question
  end

  def execute(destroy: false)
    return if question.changed? && question.narrator == question.narrator_was

    self.outdated_files = Blobs.new(question.narrator_was).execute

    if destroy
      outdated_files.purification
      return
    end

    return unless Launch.new(question, outdated_files).execute

    self.question = Standarize.new(question).execute
    blocks_processing
    outdated_files.purification
    question.save!
  end

  private

  def blocks_processing
    question.narrator['blocks'].each_with_index do |block, index|
      block = "Question::Narrator::Block::#{block['type'].classify}".safe_constantize&.new(self, index, block)&.build
      question.narrator['blocks'][index] = block
    end
  end
end
