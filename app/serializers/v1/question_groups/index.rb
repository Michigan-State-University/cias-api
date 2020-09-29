# frozen_string_literal: true

class V1::QuestionGroups::Index < BaseSerializer
  def cache_key
    "question_groups/#{question_groups.count}-#{question_groups.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    {
      question_groups: collect_question_groups
    }
  end

  private

  attr_reader :question_groups

  def collect_question_groups
    question_groups.map { |question_group| V1::QuestionGroups::Show.new(question_group: question_group).to_json }
  end
end
