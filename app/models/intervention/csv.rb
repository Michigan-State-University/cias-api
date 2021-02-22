# frozen_string_literal: true

require 'csv'

class Intervention::Csv
  attr_reader :questions_scope
  attr_accessor :data

  def initialize(intervention)
    @questions_scope = data_scope(intervention)
  end

  def execute
    collect_data
    generate
  end

  private

  def data_scope(intervention)
    Question.joins(question_group: :session)
            .where(sessions: { intervention_id: intervention.id })
            .where.not(type: %w[Question::Feedback Question::Finish Question::Information Question::ThirdParty])
            .group('sessions.position, sessions.updated_at, questions.position, questions.updated_at, questions.id')
            .order(
              'sessions.position' => :asc,
              'sessions.updated_at' => :asc,
              'questions.position' => :asc,
              'questions.updated_at' => :asc
            )
  end

  def collect_data
    self.data = Harvester.new(questions_scope).collect
  end

  def generate
    CSV.generate do |csv|
      csv << data.header
      data.rows&.each { |row| csv << row }
    end
  end
end
