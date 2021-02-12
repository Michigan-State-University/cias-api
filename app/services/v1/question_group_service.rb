# frozen_string_literal: true

class V1::QuestionGroupService
  def initialize(user, session_id)
    @user = user
    @session_id = session_id
    @question_groups = QuestionGroup.includes(:session, :questions).accessible_by(user.ability).where(session_id: session_id).order(:position)
  end

  attr_reader :user, :session_id
  attr_accessor :question_groups

  def question_group_load(qg_id)
    question_groups.find(qg_id)
  end

  def session_load
    question_groups.first.session
  end

  def questions_scope(question_ids)
    Question.accessible_by(user.ability).where(id: question_ids)
  end

  def create(question_group_params, question_ids, questions_params)
    qg_plain = QuestionGroup::Plain.new(session_id: session_id, **question_group_params)
    qg_plain.position = question_groups.where(type: 'QuestionGroup::Plain').last&.position.to_i + 1
    qg_plain.save!

    questions_scope(question_ids).update_all(question_group_id: qg_plain.id) # rubocop:disable Rails/SkipsModelValidations
    create_new_questions(qg_plain, questions_params)

    qg_plain.id
  end

  def update(question_group_id, question_group_params)
    question_group = question_group_load(question_group_id)
    question_group.update!(question_group_params)
    question_group
  end

  def destroy(question_group_id)
    question_group = question_group_load(question_group_id)
    question_group.destroy! unless question_group.finish?
  end

  def questions_change(question_group_id, question_ids)
    question_group = question_group_load(question_group_id)
    questions_scope(question_ids).update_all(question_group_id: question_group.id) # rubocop:disable Rails/SkipsModelValidations
    question_group
  end

  private

  def create_new_questions(question_group, questions_params)
    return if questions_params.blank?

    questions_params.each do |question_params|
      Question.create!(question_group_id: question_group.id,
                       position: question_group.questions.last&.position.to_i + 1,
                       **question_params.permit(:type, :title, :subtitle, :video_url, narrator: {}, settings: {}, formula: {}, body: {}))
    end
  end
end
