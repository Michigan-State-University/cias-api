# frozen_string_literal: true

module Clone::ReflectionReassignment
  private

  def reassign_reflections
    outcome.sessions.order(:position).each do |outcome_session|
      next unless outcome_session.respond_to?(:questions)

      outcome_session.questions.find_each do |question|
        reassign_question_reflections(question, outcome_session)
        remove_invalid_reflections(question)
        question.save!
      end
    end
  end

  def reassign_question_reflections(question, outcome_session)
    question.narrator['blocks'].each do |block|
      next unless block['type'] == 'Reflection'

      reflection_question_id = block['question_id']
      next if reflection_question_id.nil?

      previous_session_id_assigned = block['session_id']
      matched_session = matching_reflection_session(block['session_id'])
      matched_question = matching_reflection_question(reflection_question_id, matched_session || outcome_session)

      block['question_id'] = matched_question&.id || ''
      block['question_group_id'] = matched_question&.question_group_id || ''
      block['session_id'] = matched_session&.id || previous_session_id_assigned
    end
  end

  def matching_reflection_session(source_session_id)
    return nil if source_session_id.blank?

    source_session = source.sessions.find_by(id: source_session_id)
    return nil unless source_session

    outcome.sessions.find_by(position: source_session.position)
  end

  def matching_reflection_question(source_question_id, target_session)
    return nil if target_session.nil?

    source_question = source_reflection_question(source_question_id)
    return nil unless source_question

    target_session.questions
                  .joins(:question_group)
                  .where(question_groups: { position: source_question.question_group.position })
                  .find_by(position: source_question.position)
  end

  def source_reflection_question(source_question_id)
    Question
      .joins(question_group: :session)
      .where(sessions: { intervention_id: source.id })
      .find_by(id: source_question_id)
  end

  # Drop a reflection that, after re-pointing, still references a session that is
  # not part of the cloned intervention (a dangling cross-session reference).
  def remove_invalid_reflections(question)
    question.narrator['blocks'].delete_if do |block|
      block['type'] == 'Reflection' &&
        block['question_id'].present? &&
        block['session_id'].present? &&
        outcome_session_ids.exclude?(block['session_id'])
    end
  end

  def outcome_session_ids
    @outcome_session_ids ||= outcome.sessions.pluck(:id)
  end
end
