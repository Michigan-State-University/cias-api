# frozen_string_literal: true

class Clone::QuestionGroup < Clone::Base
  def execute
    outcome.position = position || outcome.session.question_groups.size
    clone_questions
    outcome.save!
    outcome
  end

  private

  def clone_questions
    ActiveRecord::Base.transaction do
      source.questions.order(:position).find_each do |question|
        outcome.questions << question.clone(clean_formulas: clean_formulas, position: question.position)
      end
    end
  end
end
