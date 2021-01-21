# frozen_string_literal: true

class Clone::Session < Clone::Base
  def execute
    outcome.position = position || outcome.intervention.sessions.size
    create_question_groups
    outcome.save!
    reassign_branching
    outcome
  end

  private

  def create_question_groups
    source.question_groups.order(:position).each do |question_group|
      outcome.question_groups << Clone::QuestionGroup.new(question_group,
                                                          session_id: outcome.id,
                                                          clean_formulas: false,
                                                          position: question_group.position).execute
    end
  end

  def outcome_questions
    Question.unscoped
            .includes(:question_group)
            .where(question_groups: { session_id: outcome.id })
            .order('question_groups.position ASC', 'questions.position ASC')
  end

  def reassign_branching
    outcome_questions.find_each do |question|
      question.formula['patterns'] = question.formula['patterns'].map do |pattern|
        pattern['target']['id'] = matching_outcome_target_id(pattern)
        pattern
      end
      question.save!
    end
  end

  def matching_outcome_target_id(pattern)
    target_id = pattern['target']['id']
    return target_id if pattern['target']['type'] == 'Session'

    matching_question_id(target_id)
  end

  def matching_question_id(target_id)
    target = source.questions.find(target_id)
    outcome.questions
           .joins(:question_group)
           .where(question_groups: { position: target.question_group.position })
           .find_by!(position: target.position).id
  end
end
