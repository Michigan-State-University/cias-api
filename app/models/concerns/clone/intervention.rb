# frozen_string_literal: true

class Clone::Intervention < Clone::Base
  include Clone::ReflectionReassignment

  def execute
    outcome.status = :draft
    outcome.sensitive_data_state = 'collected'
    outcome.name = "Copy of #{outcome.name}"
    outcome.is_hidden = true
    outcome.user_id = user_id if user_id.present?
    clear_organization!
    clear_cat_mh_settings!
    clear_hfhs_settings!
    outcome.save!
    assign_tags
    create_sessions
    reassign_branching
    reassign_reflections
    # Must follow reassign_reflections — raw SQL vs whole-column save!, they overwrite each other.
    apply_session_variable_renames
    outcome.update!(is_hidden: hidden)
    reset_cache_counters
    attach_logo
    attach_files
    outcome
  end

  private

  def attach_logo
    return unless source.logo.attachment

    outcome.logo.attach(io: StringIO.new(source.logo.download),
                        filename: source.logo.filename,
                        content_type: source.logo.content_type)
    outcome.logo_blob.update!(description: source.logo_blob.description)
  end

  def attach_files
    return unless source.files.attached?

    source.files.find_each do |file|
      outcome.files.attach(file.blob)
    end
  end

  def assign_tags
    outcome.tags << source.tags
  end

  def create_sessions
    source.sessions.order(:position).each do |session|
      cloned_session = Clone::Session.new(session, clone_session_options(session)).execute
      outcome.sessions << cloned_session
      next unless rename_session_variables

      variable_renames << [cloned_session.id, session.variable, cloned_session.variable]
    end
  end

  def clone_session_options(session)
    options = { intervention_id: outcome.id,
                clean_formulas: false,
                defer_reflection_reassignment: true,
                position: session.position }
    # Plain key, not params: — Clone#clone's multi-user branch drops params entirely.
    options[:variable] = cloned_session_variable(session) if rename_session_variables
    options
  end

  def cloned_session_variable(session)
    "cloned_#{session.variable}_#{session.position}"
  end

  def variable_renames
    @variable_renames ||= []
  end

  def apply_session_variable_renames
    assert_rename_namespace_disjoint!

    variable_renames.each do |session_id, old_variable, new_variable|
      V1::VariableReferences::SessionService.new(session_id, old_variable, new_variable,
                                                 include_source_session: true,
                                                 skip_chart_formulas: true).call
    end
  end

  def assert_rename_namespace_disjoint!
    overlap = variable_renames.map { |_, old, _| old } & variable_renames.map { |_, _, new| new }
    return if overlap.empty?

    raise ArgumentError, "cloned session variables collide with source variables: #{overlap.join(', ')}"
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

  def clear_hfhs_settings!
    outcome.hfhs_access = false
  end

  def reset_cache_counters
    Intervention.reset_counters(outcome.id, :navigators)
    Intervention.reset_counters(outcome.id, :conversations)
  end
end
