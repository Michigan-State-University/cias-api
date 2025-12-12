# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
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
    previous_answer_options = question.question_answers

    new_answer_options = question.extract_answers_from_params(question_params)

    changed_vars = if previous_answer_options.size == new_answer_options.size
                     changed_variables(previous_var, question_params)
                   else
                     []
                   end

    detector = V1::Question::AnswerOptionsChangeDetector.new(question)
    changed_answers_options, new_answers_to_add, deleted_answers = detect_answer_option_changes(
      detector,
      previous_answer_options,
      new_answer_options
    )

    if question.is_a?(Question::Grid)
      changed_columns, new_columns_to_add, deleted_columns = detect_grid_column_changes(detector)
    else
      changed_columns = []
      new_columns_to_add = []
      deleted_columns = []
    end

    variable_jobs_need_queuing = !changed_vars.empty?
    lock_acquired = false
    jobs_enqueued = false
    session_id = question.session.id

    begin
      if variable_jobs_need_queuing
        # rubocop:disable Rails/SkipsModelValidations
        lock_acquired = Session
                        .where(id: session_id, formula_update_in_progress: false)
                        .update_all(formula_update_in_progress: true, updated_at: Time.current)
                        .positive?
        # rubocop:enable Rails/SkipsModelValidations

        unless lock_acquired
          Rails.logger.warn "[V1::Question::Update] Failed to acquire lock for session #{session_id} - already locked"
          raise ActiveRecord::RecordNotSaved, I18n.t('question.error.formula_update_in_progress')
        end
      end

      question.assign_attributes(question_params.except(:type))
      question.execute_narrator
      question.save!

      adjust_variable_references(changed_vars)
      adjust_answer_options_references(
        changed_answers_options,
        new_answers_to_add,
        deleted_answers,
        {
          changed: changed_columns,
          new: new_columns_to_add,
          deleted: deleted_columns
        }
      )

      jobs_enqueued = true
      question
    rescue StandardError => e
      Rails.logger.error "[V1::Question::Update] FAILED TO SAVE: #{e.message}"
      Rails.logger.error "[V1::Question::Update] Backtrace: #{e.backtrace.join("\n")}"
      Rails.logger.error "[V1::Question::Update] VALIDATION FAILED: #{e.record.errors.full_messages.join(', ')}" if e.is_a?(ActiveRecord::RecordInvalid)
      Sentry.capture_exception(e)
      raise e
    ensure
      if lock_acquired && !jobs_enqueued
        Rails.logger.warn "[V1::Question::Update] Releasing formula_update_in_progress lock for session #{session_id} due to failed job enqueue"
        # rubocop:disable Rails/SkipsModelValidations
        Session.where(id: session_id).update_all(formula_update_in_progress: false, updated_at: Time.current)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end

  private

  attr_reader :question_params
  attr_accessor :question

  def adjust_variable_references(changed_vars)
    return if changed_vars.empty?

    changed_vars.each do |old_var, new_var|
      UpdateJobs::AdjustQuestionVariableReferences.perform_later(
        question.id,
        old_var,
        new_var
      )
    end
  end

  def adjust_answer_options_references(
    changed_answer_options,
    new_answer_options,
    deleted_answer_options,
    grid_columns = {}
  )
    changed_columns = grid_columns[:changed] || {}
    new_columns = grid_columns[:new] || {}
    deleted_columns = grid_columns[:deleted] || {}

    if changed_answer_options.empty? && new_answer_options.empty? &&
       deleted_answer_options.empty? && changed_columns.empty? &&
       new_columns.empty? && deleted_columns.empty?
      return
    end

    serialized_grid_columns = {
      changed: changed_columns,
      new: new_columns,
      deleted: deleted_columns
    }

    UpdateJobs::AdjustQuestionAnswerOptionsReferences.perform_later(
      question.id,
      changed_answer_options,
      new_answer_options,
      deleted_answer_options,
      serialized_grid_columns
    )
  end

  def changed_variables(previous_variables, params)
    new_vars = question.extract_variables_from_params(params)
    return [] if new_vars.empty?

    previous_variables.zip(new_vars).filter_map do |prev_var, new_var|
      next if prev_var.nil? || new_var.nil?
      next if prev_var['name'] == new_var['name']

      [prev_var['name'], new_var['name']]
    end
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

  def detect_answer_option_changes(detector, old_options, new_options)
    old_size = old_options.size
    new_size = new_options.size

    changed = []
    new_added = []
    deleted = []

    if old_size == new_size
      changed = detector.detect_changes(old_options, new_options)
    elsif old_size < new_size
      new_added = detector.detect_new_options(old_options, new_options)
    elsif old_size > new_size
      deleted = detector.detect_deleted_options(old_options, new_options)
    end

    [changed, new_added, deleted]
  end

  def detect_grid_column_changes(detector)
    previous_columns = question.question_columns
    new_columns = question.extract_columns_from_params(question_params)

    old_col_size = previous_columns.size
    new_col_size = new_columns.size

    changed = {}
    new_added = {}
    deleted = {}

    if old_col_size == new_col_size
      changed = detector.detect_column_changes(previous_columns, new_columns)
    elsif old_col_size < new_col_size
      new_added = detector.detect_new_columns(previous_columns, new_columns)
    elsif old_col_size > new_col_size
      deleted = detector.detect_deleted_columns(previous_columns, new_columns)
    end

    [changed, new_added, deleted]
  end
end

# rubocop:enable Metrics/ClassLength
