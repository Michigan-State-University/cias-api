# frozen_string_literal: true

class V1::Question::Update
  def self.call(question, question_params)
    new(question, question_params).call
  end

  def initialize(question, question_params)
    @question = question
    @question_params = question_params
  end

  def call
    raise ActiveRecord::RecordNotSaved, I18n.t('question.error.published_intervention') if question.session.published?
    raise ActiveRecord::RecordNotSaved, I18n.t('question.error.not_uniq_variable') if new_variable_is_taken?(new_variables)

    previous_var = question_variables

    changed_vars = changed_variables_preview(previous_var, question_params)
    raise ActiveRecord::RecordNotSaved, I18n.t('question.error.formula_update_in_progress') if !changed_vars.empty? && formula_update_in_progress?

    question.assign_attributes(question_params.except(:type))
    question.execute_narrator
    question.save!

    adjust_variable_references(previous_var)

    question
  end

  private

  attr_reader :question_params
  attr_accessor :question

  def adjust_variable_references(previous_variables)
    changed_vars = changed_variables(previous_variables)
    return if changed_vars.empty?

    changed_vars.each do |old_var, new_var|
      UpdateJobs::AdjustQuestionVariableReferences.perform_later(
        question.id,
        old_var,
        new_var
      )
    end
  end

  def changed_variables(previous_variables)
    previous_variables.zip(question_variables).filter_map do |prev_var, curr_var|
      next if prev_var.nil? || curr_var.nil?
      next if prev_var['name'] == curr_var['name']

      [prev_var['name'], curr_var['name']]
    end
  end

  def changed_variables_preview(previous_variables, params)
    new_vars = question.extract_variables_from_params(params)
    return [] if new_vars.empty?

    previous_variables.zip(new_vars).filter_map do |prev_var, new_var|
      next if prev_var.nil? || new_var.nil?
      next if prev_var['name'] == new_var['name']

      [prev_var['name'], new_var['name']]
    end
  end

  def formula_update_in_progress?
    question.session.intervention.formula_update_in_progress?
  end

  def question_variables
    question.question_variables.map { |var| { 'name' => var } }
  end

  def new_variables
    return [] if question.is_a?(Question::TlfbQuestion)
    return question_params&.dig(:body, :data)&.map { |row| row.dig(:variable, :name)&.downcase } if question.is_a?(Question::Multiple)

    if question.is_a?(Question::Grid)
      return question_params&.dig(:body, :data)&.first&.dig(:payload, :rows)&.map do |row|
               row.dig(:variable, :name).downcase
             end&.reject(&:empty?)
    end

    [question_params.dig(:body, :variable, :name)&.downcase]
  end

  def new_variable_is_taken?(new_variables)
    return false if new_variables.blank?

    used_variables = question.session.fetch_variables({}, question.id).pluck(:variables).flatten.map(&:downcase)

    used_variables.any? { |variable| new_variables.include?(variable) }
  end
end
