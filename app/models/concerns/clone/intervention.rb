# frozen_string_literal: true

class Clone::Intervention < Clone::Base
  def execute
    outcome.status = :draft
    outcome.save!
    create_sessions
    reassign_branching
    outcome
  end

  private

  def create_sessions
    source.sessions.order(:position).each do |session|
      outcome.sessions << Clone::Session.new(session,
                                             intervention_id: outcome.id,
                                             clean_formulas: false,
                                             position: session.position).execute
    end
  end

  def reassign_branching
    outcome.sessions.order(:position).each do |session|
      reassign_branching_between_sessions(session)
    end
  end

  def reassign_branching_between_sessions(outcome_session)
    outcome_session.formula['patterns'] = update_object_pattern(outcome_session)
    outcome_session.save!

    outcome_session.questions.find_each do |question|
      question.formula['patterns'] = update_object_pattern(question)
      question.save!
    end
  end

  def update_object_pattern(object)
    object.formula['patterns'].map do |pattern|
      index = 0
      pattern['target'].each do |current_target|
        current_target['id'] = matching_outcome_target_id(pattern, index)
        index += 1
      end
      pattern
    end
  end

  def matching_outcome_target_id(pattern, index)
    target_id = pattern['target'][index]['id']
    return target_id if pattern['target'][index]['type'] != 'Session' || target_id.empty?

    matching_session_id(target_id)
  end

  def matching_session_id(target_id)
    target_position = source.sessions.find(target_id).position
    outcome.sessions.find_by!(position: target_position).id
  end
end
