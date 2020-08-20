# frozen_string_literal: true

class Question::Narrator::Launch
  include BlockHelper
  attr_reader :question, :outdated_files
  attr_accessor :narrator

  def initialize(question, outdated_files)
    @question = question
    @narrator = question.narrator
    @outdated_files = outdated_files
  end

  def execute
    unless narrator['settings']['voice']
      outdated_files.purification
      narrator['blocks'].reject!(&method(:voice_block?))
    end
    narrator['blocks'].reject!(&method(:animation_block?)) unless narrator['settings']['animation']
    narrator['settings']['voice'] && question.narrator_changed?
  end
end
