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

    previous_var = question.body['variable']['name']
    question.assign_attributes(question_params.except(:type))
    question.execute_narrator
    question.save!
    adjust_reflections(previous_var)
    question
  end

  private

  attr_reader :question_params
  attr_accessor :question

  def adjust_reflections(previous_variable)
    return if previous_variable == include?(question.body['variable']['name'])

    UpdateJobs::AdjustQuestionReflections.perform_later(question, previous_variable)
  end
end
