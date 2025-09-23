# frozen_string_literal: true

class Import::Basic::QuestionGroupService
  include ImportOperations

  def self.call(session_id, question_group_hash)
    new(
      session_id,
      question_group_hash.except(:version)
    ).call
  end

  def initialize(session_id, question_group_hash)
    @question_group_hash = question_group_hash
    @session_id = session_id
  end

  attr_reader :question_group_hash, :session_id

  def call
    questions = question_group_hash.delete(:questions)
    question_group = QuestionGroup.create!(question_group_hash.merge({ session_id: session_id }))
    questions&.each do |question_hash|
      get_import_service_class(question_hash, Question).call(question_group.id, question_hash)
    end
  end
end
