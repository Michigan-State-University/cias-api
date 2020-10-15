# frozen_string_literal: true

class Clone::QuestionGroup < Clone::Base
  def execute
    clone_questions
    outcome
  end

  private

  def clone_questions
    ActiveRecord::Base.transaction do
      source.questions.find_each do |question|
        outcome.questions << question.clone
      end
    end
  end
end
