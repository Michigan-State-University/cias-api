# frozen_string_literal: true

class V1::VariableReferences::AnswerOptionsService < V1::VariableReferences::BaseService
  include V1::VariableReferences::AnswerOptions::SqlBuilder
  include V1::VariableReferences::AnswerOptions::PayloadNormalizer

  attr_reader :question_id, :changed_answer_values, :new_answer_options, :deleted_answer_options,
              :changed_columns, :new_columns, :deleted_columns

  def initialize(question_id, changed_answer_values, new_answer_options = [], deleted_answer_options = [], grid_columns = {})
    super()
    @question_id = question_id

    @changed_answer_values = changed_answer_values || []
    @new_answer_options = new_answer_options || []
    @deleted_answer_options = deleted_answer_options || []

    @changed_columns = grid_columns[:changed] || {}
    @new_columns = grid_columns[:new] || {}
    @deleted_columns = grid_columns[:deleted] || {}
  end

  def call
    return unless any_changes?

    ActiveRecord::Base.transaction do
      update_reflections_for_changed_answers
      add_new_reflections_for_new_answers
      delete_reflections_for_deleted_answers
      update_reflections_for_changed_columns
      add_new_reflections_for_new_columns
      delete_reflections_for_deleted_columns
    end
  rescue StandardError => e
    Rails.logger.error "[#{self.class.name}] Error in call: #{e.class} - #{e.message}"
    Rails.logger.error "[#{self.class.name}] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise
  end

  private

  def any_changes?
    changed_answers? || new_answers? || deleted_answers? ||
      changed_columns? || new_columns? || deleted_columns?
  end

  def changed_answers?
    changed_answer_values.present?
  end

  def new_answers?
    new_answer_options.present?
  end

  def deleted_answers?
    deleted_answer_options.present?
  end

  def changed_columns?
    changed_columns.present?
  end

  def new_columns?
    new_columns.present?
  end

  def deleted_columns?
    deleted_columns.present?
  end

  def question
    @question ||= Question.find(@question_id)
  end

  def source_session
    @source_session ||= question.session
  end

  # Execute SQL for both session scopes: source session and other sessions in intervention
  def execute_for_both_session_types
    [false, true].each do |exclude_source|
      base_query = build_question_base_query(source_session, exclude_source)
      sql = yield(base_query)

      next if sql.nil?

      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def update_reflections_for_changed_answers
    return unless changed_answers?

    execute_for_both_session_types do |base_query|
      build_update_reflection_payloads_sql(base_query)
    end
  end

  def add_new_reflections_for_new_answers
    return unless new_answers?

    execute_for_both_session_types do |base_query|
      build_add_new_reflections_sql(base_query)
    end
  end

  def delete_reflections_for_deleted_answers
    return unless deleted_answers?

    execute_for_both_session_types do |base_query|
      build_delete_reflections_sql(base_query)
    end
  end

  def update_reflections_for_changed_columns
    return unless changed_columns?

    execute_for_both_session_types do |base_query|
      build_update_column_payloads_sql(base_query)
    end
  end

  def add_new_reflections_for_new_columns
    return unless new_columns?

    rows = question.question_answers

    execute_for_both_session_types do |base_query|
      build_add_new_column_reflections_sql(base_query, rows)
    end
  end

  def delete_reflections_for_deleted_columns
    return unless deleted_columns?

    execute_for_both_session_types do |base_query|
      build_delete_column_reflections_sql(base_query)
    end
  end
end
