# frozen_string_literal: true

class V1::Question::Move
  prepend Database::Transactional

  def self.call(session, values)
    new(session, values).call
  end

  def initialize(session, values)
    @session = session
    @rows = V1::Positions::Rows.new(values, uuid_keys: %i[id question_group_id])
  end

  def call
    ids = rows.ids
    return if ids.empty?

    V1::Positions.ensure_in_scope!(session.questions, ids)
    V1::Positions.ensure_in_scope!(session.question_groups, question_counts.keys)

    move_questions(ids)
    session.question_groups.empty_non_finish.delete_all
    update_question_counts
  end

  private

  attr_reader :session, :rows

  def move_questions(ids)
    table = ::Question.arel_table
    session.questions.where(id: ids).update_all( # rubocop:disable Rails/SkipsModelValidations
      question_group_id: uuid_cast(V1::Positions.case_by_id(table, rows.mapping(:question_group_id))),
      position: V1::Positions.case_by_id(table, rows.mapping(:position)),
      updated_at: Time.current
    )
  end

  def update_question_counts
    session.question_groups.where(id: question_counts.keys).update_all( # rubocop:disable Rails/SkipsModelValidations
      questions_count: V1::Positions.case_by_id(::QuestionGroup.arel_table, question_counts),
      updated_at: Time.current
    )
  end

  def question_counts
    @question_counts ||= rows.column(:question_group_id).tally
  end

  def uuid_cast(node)
    Arel::Nodes::NamedFunction.new('CAST', [node.as(Arel.sql('uuid'))])
  end
end
