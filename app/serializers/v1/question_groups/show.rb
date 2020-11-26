# frozen_string_literal: true

class V1::QuestionGroups::Show < BaseSerializer
  def cache_key
    "question_group/#{question_group.id}-#{question_group.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: question_group.id,
      type: question_group.type,
      title: question_group.title,
      position: question_group.position,
      session_id: question_group.session_id,
      questions: collect_questions
    }
  end

  private

  attr_reader :question_group

  def collect_questions
    question_group.questions.map { |question| V1::Questions::Show.new(question: question).to_json }
  end
end
