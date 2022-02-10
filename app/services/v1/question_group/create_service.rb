# frozen_string_literal: true

class V1::QuestionGroup::CreateService
  attr_reader :questions_params, :question_group_params, :session
  attr_accessor :questions

  def self.call(question_group_params, questions, questions_params, session)
    new(question_group_params, questions, questions_params, session).call
  end

  def initialize(question_group_params, questions, questions_params, session)
    @question_group_params = question_group_params
    @questions = questions
    @questions_params = questions_params
    @session = session
  end

  def call
    raise ActiveRecord::ActiveRecordError if questions.tlfb.any?

    qg_plain = QuestionGroup.new(session_id: session.id, **question_group_params)
    qg_plain.position = session.question_groups.where.not(type: 'QuestionGroup::Finish').last&.position.to_i + 1
    qg_plain.save!

    questions.update_all(question_group_id: qg_plain.id) # rubocop:disable Rails/SkipsModelValidations
    create_new_questions(qg_plain, questions_params)

    qg_plain
  end

  private

  def create_new_questions(question_group, questions_params)
    return if questions_params.blank?

    questions_params.each do |question_params|
      Question.create!(question_group_id: question_group.id,
                       position: question_group.questions.last&.position.to_i + 1,
                       **question_params.permit(:type, :title, :subtitle, :video_url, narrator: {}, settings: {},
                                                                                      formula: {}, body: {}))
    end
  end
end
