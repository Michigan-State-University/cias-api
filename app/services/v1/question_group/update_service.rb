# frozen_string_literal: true
# to delete
class V1::QuestionGroup::UpdateService
  attr_accessor :question_group
  attr_reader :question_group_params

  def self.call(question_group, question_group_params)
    new(question_group, question_group_params).call
  end

  def initialize(question_group, question_group_params)
    @question_group_params = question_group_params
    @question_group = question_group
  end

  def call
    question_group.update!(question_group_params)
    question_group.reload
  end
end
