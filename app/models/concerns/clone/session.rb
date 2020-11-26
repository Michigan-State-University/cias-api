# frozen_string_literal: true

class Clone::Session < Clone::Base
  def execute
    create_question_groups
    outcome.position = outcome.problem.sessions.size
    outcome.save!
    outcome
  end

  private

  def create_question_groups
    source.question_groups.each do |question_group|
      Clone::QuestionGroup.new(question_group, session_id: outcome.id).execute
    end
  end
end
