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
      source.questions.order(:position).each do |question|
        next if hf_initial_screen?(question) && outcome_without_hf_access?

        outcome.questions << Clone::Question.new(question,
                                                 question_group_id: outcome.id,
                                                 clean_formulas: clean_formulas,
                                                 position: question.position, session_variables: session_variables).execute
      end
    end
  end

  def hf_initial_screen?(question)
    question.is_a?(::Question::HenryFordInitial)
  end

  def outcome_without_hf_access?
    !outcome.session.intervention.hfhs_access
  end
end
