# frozen_string_literal: true

class V1::ChartStatistics::UnansweredOwningQuestions
  def self.none_answered?(user_session, missing_vars)
    new(user_session, missing_vars).none_answered?
  end

  def initialize(user_session, missing_vars)
    @user_session = user_session
    @missing_vars = missing_vars
  end

  def none_answered?
    return false if missing_vars.empty?
    return false if owning_question_ids.empty?

    answered_question_ids.empty?
  end

  private

  attr_reader :user_session, :missing_vars

  def qualified_pairs
    @qualified_pairs ||= missing_vars.filter_map { |variable| variable.split('.', 2) if variable.include?('.') }.to_set
  end

  def bare_var_names
    @bare_var_names ||= missing_vars.reject { |variable| variable.include?('.') }
  end

  def owning_question_ids
    @owning_question_ids ||= intervention_questions.select { |question| owns_missing_variable?(question) }.map(&:id)
  end

  def intervention_questions
    Question.joins(question_group: :session)
            .preload(question_group: :session)
            .where(sessions: { intervention_id: user_session.session.intervention_id })
  end

  def owns_missing_variable?(question)
    variables = question.question_variables.compact
    return true if variables.intersect?(bare_var_names)

    session_variable = question.question_group.session.variable
    variables.any? { |variable| qualified_pairs.include?([session_variable, variable]) }
  end

  # `.map(&:id)`, never `.pluck(:id)`: `latest_user_sessions` is a `DISTINCT ON` relation
  # (user_intervention.rb:20-22) and `pluck` REPLACES its `select_values`, so a multiple-fill
  # retake would contribute its older fill's answers as well.
  def answered_question_ids
    latest_user_session_ids = user_session.user_intervention.latest_user_sessions.map(&:id)

    Answer.confirmed
          .where(user_session_id: latest_user_session_ids, question_id: owning_question_ids)
          .pluck(:question_id).uniq
  end
end
