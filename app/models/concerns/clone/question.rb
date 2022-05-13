# frozen_string_literal: true

class Clone::Question < Clone::Base
  def execute
    attach_image
    clean_outcome_formulas if clean_formulas
    outcome.position = position || outcome.question_group.questions.size
    outcome.save!
    outcome
  end

  private

  def attach_image
    outcome.image.attach(source.image.blob) if source.image.attachment
  end

  def clean_outcome_formulas
    @session_variables ||= outcome.question_group.session.session_variables.uniq
    outcome.variable_clone_prefix(@session_variables)
    outcome.formulas = Question.assign_default_values('formulas')
  end
end
