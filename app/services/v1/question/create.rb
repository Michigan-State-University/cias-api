# frozen_string_literal: true

class V1::Question::Create
  def self.call(question_group, question_params)
    new(question_group, question_params).call
  end

  def initialize(question_group, question_params)
    @question_group = question_group
    @questions_scope = question_group.questions.order(:position)
    @question_params = question_params
  end

  def call
    raise ActiveRecord::ActiveRecordError if question_group.type.eql?('QuestionGroup::Tlfb')

    extend_question_params(question_params)
    question = questions_scope.new(question_params)
    question.position = questions_scope.last&.position.to_i + 1
    question.save!
    question
  end

  private

  attr_reader :question_params, :question_group
  attr_accessor :questions_scope

  def extend_question_params(question_params)
    if question_params[:type].in?(questions_with_multiple_simple_answer)
      question_params.dig(:body, :data).each do |answer_params|
        answer_params[:id] = SecureRandom.uuid
      end
    elsif question_params[:type] == Question::Grid.name
      question_params.dig(:body, :data).each do |data|
        data.dig(:payload, :rows).each do |row|
          row[:id] = SecureRandom.uuid
        end

        data.dig(:payload, :columns).each do |col|
          col[:id] = SecureRandom.uuid
        end
      end
    end
  end

  def questions_with_multiple_simple_answer
    @questions_with_multiple_simple_answer ||= %w[Question::Single Question::Multiple Question::ThirdParty]
  end
end
