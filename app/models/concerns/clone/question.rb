# frozen_string_literal: true

class Clone::Question < Clone::Base
  def execute
    attach_image
    clean_outcome_formulas if clean_formulas
    outcome.position = position || outcome.question_group.questions.size
    outcome.save!
    p "CLONE DEBUG FINISH COPY QUESTION #{position}"
    outcome
  end

  private

  def attach_image
    outcome.image.attach(source.image.blob) if source.image.attachment
  end

  def clean_outcome_formulas
    taken_variables = outcome.question_group.session.session_variables.uniq
    outcome.variable_clone_prefix(taken_variables)
    outcome.formula = Question.assign_default_values('formula')
  end
end
