# frozen_string_literal: true

class Clone::Intervention < Clone::Base
  def execute
    outcome.status = :draft
    outcome.sensitive_data_state = 'collected'
    outcome.name = "Copy of #{outcome.name}"
    outcome.is_hidden = true
    clear_organization!
    clear_cat_mh_settings!
    outcome.save!
    create_sessions
    reassign_branching
    outcome.update!(is_hidden: hidden)
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
    outcome_session.formulas.each do |formula|
      formula['patterns'] = update_object_pattern(outcome_session, formula)
    end
    outcome_session.save!

    return unless outcome_session.respond_to?(:questions)

    outcome_session.questions.find_each do |question|
      question.formulas.each do |formula|
        formula['patterns'] = update_object_pattern(question, formula)
      end
      question.save!
    end
  end

  def update_object_pattern(object, formula)
    formula['patterns'].map do |pattern|
      index = 0
      pattern['target'].each do |current_target|
        current_target['id'] = matching_outcome_target_id(pattern, index, object)
        index += 1
      end
      pattern
    end
  end

  def matching_outcome_target_id(pattern, index, object)
    target_id = pattern['target'][index]['id']
    return check_if_question_exists(target_id, object) if pattern['target'][index]['type'] != 'Session' || target_id.empty?

    matching_session_id(target_id)
  end

  def matching_session_id(target_id)
    target = check_if_session_exists(target_id)
    if target
      outcome.sessions.find_by!(position: target.position).id
    else
      ''
    end
  end

  def check_if_question_exists(target_id, question)
    return '' if target_id.empty?

    question.session.questions.find(target_id).id
  rescue ActiveRecord::RecordNotFound
    ''
  end

  def check_if_session_exists(target_id)
    source.sessions.find(target_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def clear_organization!
    return if outcome.organization.blank?

    outcome.organization = nil
  end

  def clear_cat_mh_settings!
    outcome.cat_mh_application_id = nil
    outcome.cat_mh_organization_id = nil
    outcome.cat_mh_pool = nil
    outcome.created_cat_mh_session_count = 0
  end
end
