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
    outcome_session.questions.find_each do |question|
      question.formula['patterns'] = question.formula['patterns'].map do |pattern|
        pattern['target']['id'] = matching_outcome_target_id(pattern)
        pattern
      end
      question.save!
    end
  end

  def matching_outcome_target_id(pattern)
    target_id = pattern['target']['id']
    return target_id if pattern['target']['type'] != 'Session'

    matching_session_id(target_id)
  end

  def matching_session_id(target_id)
    target_position = source.sessions.find(target_id).position
    outcome.sessions.find_by!(position: target_position).id
  end
end
