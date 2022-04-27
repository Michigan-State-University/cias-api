# frozen_string_literal: true

class V1::QuestionGroup::ShareInternallyService
  def self.call(target_sessions, selected_groups_with_questions)
    new(target_sessions, selected_groups_with_questions).call
  end

  def initialize(target_sessions, selected_groups_with_questions)
    @sessions = target_sessions
    @question_groups_with_specific_questions = selected_groups_with_questions
  end

  def call
    ActiveRecord::Base.transaction do
      sessions.each do |session|
        V1::QuestionGroup::DuplicateWithStructureService.call(session, question_groups_with_specific_questions)
      end
    end
  end

  attr_accessor :sessions
  attr_reader :question_groups_with_specific_questions
end
