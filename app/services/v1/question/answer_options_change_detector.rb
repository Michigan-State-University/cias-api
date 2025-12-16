# frozen_string_literal: true

class V1::Question::AnswerOptionsChangeDetector
  attr_reader :question

  def initialize(question)
    @question = question
  end

  delegate :detect_changes, to: :detector_service

  delegate :detect_new_options, to: :detector_service

  delegate :detect_deleted_options, to: :detector_service

  delegate :detect_column_changes, to: :detector_service

  delegate :detect_new_columns, to: :detector_service

  delegate :detect_deleted_columns, to: :detector_service

  private

  def detector_service
    @detector_service ||= case question
                          when ::Question::Single
                            V1::Question::AnswerOptionsChangeDetectors::SingleDetector.new(question)
                          when ::Question::Multiple
                            V1::Question::AnswerOptionsChangeDetectors::MultipleDetector.new(question)
                          when ::Question::Grid
                            V1::Question::AnswerOptionsChangeDetectors::GridDetector.new(question)
                          else
                            V1::Question::AnswerOptionsChangeDetectors::BaseDetector.new(question)
                          end
  end
end
