# frozen_string_literal: true

class Clone::QuestionGroup < Clone::Base
  def execute
    clone_questions
    outcome.save!
    outcome
  end

  private

  def clone_questions
    ActiveRecord::Base.transaction do
      source.questions.order(:position).each do |question|
        outcome.questions << Clone::Question.new(question,
                                                 question_group_id: outcome.id,
                                                 clean_formulas: clean_formulas,
                                                 position: question.position, session_variables: session_variables).execute
      end
    end
  end
end
