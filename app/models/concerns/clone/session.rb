# frozen_string_literal: true

class Clone::Session < Clone::Base
  def execute
    outcome.position = position || outcome.intervention.sessions.size
    outcome.clear_formula if clean_formulas
    create_question_groups
    outcome.save!
    create_sms_plans
    reassign_branching
    reassign_reflections
    outcome
  end

  private

  def create_question_groups
    destroy_default_finish_question_group

    source.question_groups.order(:position).each do |question_group|
      outcome.question_groups << Clone::QuestionGroup.new(question_group,
                                                          session_id: outcome.id,
                                                          questions_count: 0,
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
    return target_id if pattern['target']['type'] == 'Session' || target_id.empty?

    matching_question_id(target_id)
  end

  def matching_question_id(target_id)
    target = source.questions.find(target_id)
    outcome.questions
           .joins(:question_group)
           .where(question_groups: { position: target.question_group.position })
           .find_by!(position: target.position).id
  end

  def reassign_reflections
    outcome_questions.each do |question|
      question.narrator['blocks'].each do |block|
        next block unless block['type'] == 'Reflection'

        reflection_question_id = block['question_id']

        next block if reflection_question_id.nil?

        matched_reflection_question_id = matching_question_id(reflection_question_id)
        block['question_id'] = matched_reflection_question_id
      end
      question.save!
    end
  end

  def destroy_default_finish_question_group
    outcome.question_groups.first.destroy
  end

  def create_sms_plans
    outcome.sms_plans_count = 0
    source.sms_plans.each do |plan|
      new_sms_plan = SmsPlan.new(plan.slice(*SmsPlan::ATTR_NAMES_TO_COPY))
      outcome.sms_plans << new_sms_plan

      plan.variants.each do |variant|
        new_sms_plan.variants << SmsPlan::Variant.new(variant.slice(SmsPlan::Variant::ATTR_NAMES_TO_COPY))
      end
    end
  end
end
