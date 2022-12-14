# frozen_string_literal: true

class Import::V1::QuestionService < Import::Basic::QuestionService
  def initialize(question_group_id, question_hash)
    super(question_group_id, question_hash)
    question_hash[:narrator][:settings][:character] = 'peedy'
  end
end
