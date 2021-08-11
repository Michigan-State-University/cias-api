# frozen_string_literal: true

class Question::Narrator
  include BlockHelper

  attr_accessor :question, :outdated_files

  def initialize(question)
    @question = question
  end

  def execute(destroy: false)
    return if question.changed? && question.narrator == question.narrator_was && !question.duplicated

    self.outdated_files = Blobs.call(question.narrator_was, question.duplicated)
    if destroy
      outdated_files.purge
      return
    end

    # this returns voice settings for the question and clears both animation and voice blocks unless the settings are specified
    return unless Launch.call(question, outdated_files)

    self.question = Standarize.call(question) # this clears the empty narrator blocks from the question
    process_blocks
    outdated_files.purge
    question.save!
  end

  private

  def process_blocks
    question.narrator['blocks'].each_with_index do |block, index|
      block = "Question::Narrator::Block::#{block['type'].classify}".safe_constantize&.new(self, index, block)&.build
      question.narrator['blocks'][index] = block
    end
  end
end
