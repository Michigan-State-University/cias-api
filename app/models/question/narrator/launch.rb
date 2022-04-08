# frozen_string_literal: true

class Question::Narrator::Launch
  include BlockHelper
  attr_reader :question, :outdated_files
  attr_accessor :narrator

  def self.call(question, outdated_files)
    new(question, outdated_files).call
  end

  def initialize(question, outdated_files)
    @question = question
    @narrator = question.narrator
    @outdated_files = outdated_files
  end

  def call
    unless narrator['settings']['voice']
      outdated_files.purge
      narrator['blocks'].reject!(&method(:voice_block?))
    end
    narrator['blocks'].reject!(&method(:animation_block?)) unless narrator['settings']['animation']
    narrator['settings']['voice']
  end
end
