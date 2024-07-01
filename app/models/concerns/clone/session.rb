# frozen_string_literal: true

class Clone::Session < Clone::Base
  def execute
    outcome.position = position || outcome.intervention.sessions.size
    outcome.clear_formulas if clean_formulas
    outcome.days_after_date_variable_name = nil if clean_formulas
    ActiveRecord::Base.transaction do
      create_question_groups
      outcome.save!
      create_sms_plans
      create_report_templates
      outcome_questions_reassignment
      remove_hf_initial_screen unless outcome_with_hf_access?
      reassign_report_templates_to_third_party_screens
      reassign_tests
    end
    outcome
  end

  private

  def remove_hf_initial_screen
    outcome_questions.where(type: 'Question::HenryFordInitial').destroy_all
  end

  def outcome_with_hf_access?
    outcome.intervention.hfhs_access
  end

  def create_question_groups
    # CAT-MH sessions won't have question groups so it will throw an error if we try to access them
    return unless source.question_groups.any?

    destroy_default_finish_question_group

    source.question_groups.order(:position).each do |question_group|
      outcome.question_groups << Clone::QuestionGroup.new(question_group,
                                                          session_id: outcome.id,
                                                          questions_count: 0,
                                                          clean_formulas: false,
                                                          position: question_group.position, session_variables: session_variables).execute
    end
  end

  def outcome_questions
    @outcome_questions ||= Question.unscoped
                                   .includes(:question_group)
                                   .where(question_groups: { session_id: outcome.id })
                                   .order('question_groups.position ASC', 'questions.position ASC')
  end

  def outcome_questions_reassignment
    outcome_questions.find_each do |question|
      question = reassign_branching_question(question)
      question = reassign_question_reflections(question)
      question = remove_invalid_reflections(question) if clone_single_session?
      question.save!
    end
  end

  def clone_single_session?
    outcome.intervention_id != source.intervention_id
  end

  def remove_invalid_reflections(question)
    question.narrator['blocks'].delete_if do |block|
      block['type'] == 'Reflection' && block['question_id'].present? && !session_exists_inside_target_intervention?(question, block['session_id'])
    end
    question
  end

  def session_exists_inside_target_intervention?(question, session_id)
    session_id.nil? || (question.session.id != session_id && question.session.intervention.sessions.pluck(:id).include?(session_id))
  end

  def reassign_branching_question(question)
    question.formulas.each do |formula|
      formula['patterns'] = formula['patterns'].map do |pattern|
        index = 0
        pattern['target'].each do |current_target|
          current_target['id'] =
            if current_target['type'].eql?('Question::HenryFordInitial')
              nil
            else
              matching_outcome_target_id(pattern, index)
            end
          index += 1
        end
        pattern['target'].delete_if { |branch| branch['id'].nil? }
        pattern
      end
      formula['patterns'].delete_if { |pattern| pattern['target'].empty? }
    end
    question
  end

  def matching_outcome_target_id(pattern, index)
    target_id = pattern['target'][index]['id']
    return check_if_session_exists(target_id)&.id if pattern['target'][index]['type'].include?('Session') || target_id.empty?

    matching_question(target_id)&.id || ''
  end

  def matching_question(target_id, target_session = nil)
    target = check_if_question_exists(target_id)
    return unless target

    target_session ||= outcome
    target_session.questions
                      .joins(:question_group)
                      .where(question_groups: { position: target.question_group.position })
                      .find_by!(position: target.position)
  end

  def matching_session(target_id)
    target = check_if_session_exists(target_id)
    return unless target

    outcome.intervention.sessions.find_by!(position: target.position)
  end

  def check_if_session_exists(target_id)
    return nil if target_id&.empty?

    source.intervention.sessions.find(target_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def check_if_question_exists(target_id)
    Question
      .joins(question_group: { session: :intervention })
      .where(intervention: { id: source.intervention.id })
      .find(target_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def reassign_question_reflections(question)
    question.narrator['blocks'].each do |block|
      next block unless block['type'] == 'Reflection'

      reflection_question_id = block['question_id']

      next block if reflection_question_id.nil?

      previous_session_id_assigned = block['session_id']
      matched_reflection_session = matching_session(block['session_id'])
      matched_reflection_question = matching_question(reflection_question_id, matched_reflection_session)
      block['question_id'] = matched_reflection_question&.id || ''
      block['question_group_id'] = matched_reflection_question&.question_group_id || ''
      block['session_id'] = matched_reflection_session&.id || previous_session_id_assigned
    end
    question
  end

  def destroy_default_finish_question_group
    outcome.question_groups.first.destroy
  end

  def create_sms_plans
    outcome.sms_plans_count = 0
    source.sms_plans.each do |plan|
      new_sms_plan = SmsPlan.new(plan.slice(*SmsPlan::ATTR_NAMES_TO_COPY))
      new_sms_plan.no_formula_attachment.attach(plan.no_formula_attachment.blob) if plan.no_formula_attachment.attached?
      outcome.sms_plans << new_sms_plan

      plan.variants.each { |variant| create_and_assign_variant(variant, new_sms_plan) }

      plan.alert_phones.each do |alert_phone|
        new_sms_plan.alert_phones << AlertPhone.new(sms_plan: new_sms_plan, phone: alert_phone.phone)
      end
    end
  end

  def create_report_templates
    source.report_templates.each do |report_template|
      outcome.report_templates << Clone::ReportTemplate.new(report_template, params: { session_id: outcome.id }, set_flag: false).execute
    end
    Session.reset_counters(outcome.id, :report_templates)
  end

  def reassign_report_templates_to_third_party_screens
    # pairs of ids of corresponding report templates in source and outcome
    report_template_corresponding_ids = ReportTemplate
                                          .joins('JOIN report_templates other ON report_templates.name = other.name')
                                          .where('report_templates.session_id': source.id, 'other.session_id': outcome.id)
                                          .where('report_templates.report_for': :third_party, 'other.report_for': :third_party)
                                          .pluck('report_templates.id', 'other.id').to_h

    Question::ThirdParty.includes(:question_group).where(question_groups: { session_id: outcome.id }).find_each do |third_party_question|
      third_party_question.body_data.each do |third_party_question_body_data_element|
        new_report_template_ids = third_party_question_body_data_element['report_template_ids'].each_with_object([]) do |report_template_id, arr|
          new_report_template_id = report_template_corresponding_ids[report_template_id]
          arr << new_report_template_id unless new_report_template_id.nil?
        end
        third_party_question_body_data_element['report_template_ids'] = new_report_template_ids
      end
      third_party_question.save!
    end
  end

  def reassign_tests
    return if source.instance_of?(Session::Classic) || source.instance_of?(Session::Sms)

    source.cat_mh_test_types.each do |test_type|
      outcome.cat_mh_test_types << test_type
    end
  end

  def create_and_assign_variant(variant, new_sms_plan)
    new_variant = SmsPlan::Variant.new(variant.slice(SmsPlan::Variant::ATTR_NAMES_TO_COPY))
    new_variant.attachment.attach(variant.attachment.blob) if variant.attachment.attached?
    new_sms_plan.variants << new_variant
  end
end
