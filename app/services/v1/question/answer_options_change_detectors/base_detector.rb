# frozen_string_literal: true

class V1::Question::AnswerOptionsChangeDetectors::BaseDetector
  attr_reader :question

  def initialize(question)
    @question = question
  end

  def detect_changes(_old_options, _new_options)
    []
  end

  def detect_new_options(_old_options, _new_options)
    []
  end

  def detect_deleted_options(_old_options, _new_options)
    []
  end

  def detect_column_changes(_old_columns, _new_columns)
    {}
  end

  def detect_new_columns(_old_columns, _new_columns)
    {}
  end

  def detect_deleted_columns(_old_columns, _new_columns)
    {}
  end

  private

  def duplicate_values?(options)
    value_counts = options.each_with_object(Hash.new(0)) { |opt, counts| counts[opt['value']] += 1 }
    value_counts.values.any? { |count| count > 1 }
  end
end
