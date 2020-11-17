# frozen_string_literal: true

class Clone::Intervention < Clone::Base
  def execute
    create_question_groups
    outcome.position = outcome.problem.interventions.size
    outcome.save!
    outcome
  end

  private

  def create_question_groups
    source.question_groups.each do |question_group|
      Clone::QuestionGroup.new(question_group, intervention_id: outcome.id).execute
    end
  end
end
