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

    question.assign_attributes(question_params.except(:type))
    question.execute_narrator
    question.save!
    question
  end

  private

  attr_reader :question_params
  attr_accessor :question

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
    return if new_variables.blank?

    used_variables = question.session.fetch_variables({}, question.id).pluck(:variables).flatten.map(&:downcase)

    used_variables.any? { |variable| new_variables.include?(variable) }
  end
end
