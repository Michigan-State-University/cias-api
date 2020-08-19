# frozen_string_literal: true

class Clone::Intervention < Clone::Base
  def execute
    create_questions
    outcome
  end

  private

  def create_questions
    source.questions.each do |question|
      Clone::Question.new(question, intervention_id: outcome.id).execute
    end
  end
end
