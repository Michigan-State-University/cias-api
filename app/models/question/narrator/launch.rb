# frozen_string_literal: true

class Question::Narrator::Launch
  attr_reader :question, :outdated_files

  def initialize(question, outdated_files)
    @question = question
    @outdated_files = outdated_files
  end

  def execute
    unless question.narrator['settings']['voice']
      outdated_files.purification
      false
    end
    question.narrator['settings']['voice'] && question.narrator_changed?
  end
end
