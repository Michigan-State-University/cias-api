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

    question.assign_attributes(question_params.except(:type))
    question.execute_narrator
    question.save!
    question
  end

  private

  attr_reader :question_params
  attr_accessor :question
end
