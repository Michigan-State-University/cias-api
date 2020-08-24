# frozen_string_literal: true

require 'csv'

class Problem::Csv
  attr_reader :questions_scope
  attr_accessor :data

  def initialize(problem)
    @questions_scope = data_scope(problem)
  end

  def execute
    collect_data
    generate
  end

  private

  def data_scope(problem)
    Question.joins(:intervention, answers: :user).
      where(interventions: { problem_id: problem.id }).
      group('interventions.position, interventions.updated_at, questions.position, questions.updated_at, questions.id').
      order(
        'interventions.position' => :asc,
        'interventions.updated_at' => :asc,
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
