# frozen_string_literal: true

class FormulaInterface::Variables
  attr_reader :question
  attr_accessor :outcome

  def initialize(question)
    @question = question
    @outcome = {}
  end

  def collect
    collection_scoped.each_row do |question|
      # TODO: provide variables and values through Hashie or
      # dedicated class/methods
      # question.extend Hashie::Extensions::DeepFind
      # outcome.merge(question.body_data.deep_find_all('variable'))
    end
    outcome
  end

  private

  def collection_scoped
    questions_scope.where('order <= ?', order).order(:order)
  end

  def questions_scope
    @questions_scope ||= question.intervention.questions
  end
end
