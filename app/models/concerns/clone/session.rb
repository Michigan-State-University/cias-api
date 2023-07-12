# frozen_string_literal: true

class Clone::Session < Clone::Base
  def execute
    outcome.position = position || outcome.intervention.sessions.size
    outcome.clear_formulas if clean_formulas
    outcome.days_after_date_variable_name = nil
    ActiveRecord::Base.transaction do
      create_question_groups
      outcome.save!
      create_sms_plans
      create_report_templates
      outcome_questions_reassignment
      reassign_report_templates_to_third_party_screens
      reassign_tests
    end
    outcome
  end

  private

  def create_question_groups
    # CAT-MH sessions won't have question groups so it will throw an error if we try to access them
    return unless source.respond_to?(:question_groups)

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
            .order('question_groups.position ASC', 'question.position ASC')
  end

  def outcome_questions_reassignment
    outcome_questions.find_each do |question|
      question = reassign_branching_question(question)
      question = reassign_question_reflections(question)
      question.save!
    end
  end

  def reassign_branching_question(question)
    question.formulas.each do |formula|
      formula['patterns'] = formula['patterns'].map do |pattern|
        index = 0
        pattern['target'].each do |current_target|
          current_target['id'] = matching_outcome_target_id(pattern, index)
          index += 1
        end
        pattern
      end
    end
    question
  end

  def matching_outcome_target_id(pattern, index)
    target_id = pattern['target'][index]['id']
    return check_if_session_exists(target_id) if pattern['target'][index]['type'].include?('Session') || target_id.empty?

    matching_question_id(target_id)
  end

  def matching_question_id(target_id)
    target = check_if_question_exists(target_id)
    if target
      outcome.questions
          .joins(:question_group)
          .where(question_groups: { position: target.question_group.position })
          .find_by!(position: target.position).id
    else
      ''
    end
  end

  def check_if_session_exists(target_id)
    return '' if target_id.empty?

    source.intervention.sessions.find(target_id).id
  rescue ActiveRecord::RecordNotFound
    ''
  end

  def check_if_question_exists(target_id)
    source.questions.find(target_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def reassign_question_reflections(question)
    question.narrator['blocks'].each do |block|
      next block unless block['type'] == 'Reflection'

      reflection_question_id = block['question_id']

      next block if reflection_question_id.nil?

      matched_reflection_question_id = matching_question_id(reflection_question_id)
      block['question_id'] = matched_reflection_question_id
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
    outcome.report_templates_count = 0
    source.report_templates.each do |report_template|
      new_report_template = ReportTemplate.new(report_template.slice(*ReportTemplate::ATTR_NAMES_TO_COPY))
      outcome.report_templates << new_report_template

      new_report_template.logo.attach(report_template.logo.blob) if report_template.logo.attachment
      new_report_template.pdf_preview.attach(report_template.pdf_preview.blob) if report_template.pdf_preview.attachment

      report_template.sections.each do |section|
        new_section = ReportTemplate::Section.new(section.slice(*ReportTemplate::Section::ATTR_NAMES_TO_COPY))
        new_report_template.sections << new_section

        section.variants.each do |variant|
          new_variant = ReportTemplate::Section::Variant.new(variant.slice(*ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY))
          new_section.variants << new_variant

          new_variant.image.attach(variant.image.blob) if variant.image.attachment
        end
      end
    end
  end

  def reassign_report_templates_to_third_party_screens
    source_third_party_report_templates = source.report_templates.third_party
    outcome_third_party_report_templates = outcome.report_templates.third_party

    Question::ThirdParty.includes(:question_group).where(question_groups: { session_id: outcome.id }).find_each do |third_party_question|
      third_party_question.body_data.each do |third_party_question_body_data_element|
        report_template_ids = third_party_question_body_data_element['report_template_ids']
        new_report_template_ids = report_template_ids.each_with_object([]) do |report_template_id, new_report_template_ids| # rubocop:disable Lint/ShadowingOuterLocalVariable
          source_report_template = source_third_party_report_templates.find(report_template_id)
          outcome_report_template_id = outcome_third_party_report_templates.find_by(name: source_report_template.name)&.id
          new_report_template_ids << outcome_report_template_id
        end
        third_party_question_body_data_element['report_template_ids'] = new_report_template_ids
      end
      third_party_question.save!
    end
  end

  def reassign_tests
    return if source.instance_of? Session::Classic

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
