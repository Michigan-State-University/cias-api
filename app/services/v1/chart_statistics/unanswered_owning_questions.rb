# frozen_string_literal: true

# The legacy "did the participant actually reach every question the formula references?"
# guard, extracted from `V1::ChartStatistics::Create` when phase 6 pushed that service past
# `Metrics/ClassLength`. Extracted verbatim; the ownership lookup was then fixed to key on the
# session variable as well as the question variable (see `qualified_pairs`) - the only intended
# behaviour change, and it only ever makes the guard fire LESS often.
#
# True when at least one question that OWNS one of `missing_vars` has no confirmed answer
# across the participant's latest sessions - i.e. the variable is missing because the
# question was branched around, timed out or never reached, rather than because a
# multi-select option went unselected (which legitimately 0-fills).
#
# Only consulted for charts WITHOUT the validity gate (`min_answered_variables == 0`): an
# explicit minimum supersedes it, because the chart owner has declared how many answers
# are enough and the remaining variables 0-fill.
class V1::ChartStatistics::UnansweredOwningQuestions
  def self.call(user_session, missing_vars)
    new(user_session, missing_vars).call
  end

  def initialize(user_session, missing_vars)
    @user_session = user_session
    @missing_vars = missing_vars
  end

  def call
    return false if missing_vars.empty?
    return false if owning_question_ids.empty?

    (owning_question_ids - answered_question_ids).any?
  end

  private

  attr_reader :user_session, :missing_vars

  # A chart formula qualifies every variable with its session variable ("s5551_c.q4"), and two
  # sessions of ONE intervention may legitimately carry the same question variable: copying a
  # session renames the session variable (`clone_jobs/session.rb:15`) but never the question
  # variables inside it. Attributing a missing variable by bare name therefore also pulls in the
  # untouched twin in the copied session - which the participant never opened - and reports it as
  # unanswered, silently dropping them from every ungated chart. Match the pair instead.
  def qualified_pairs
    @qualified_pairs ||= missing_vars.filter_map { |variable| variable.split('.', 2) if variable.include?('.') }.to_set
  end

  # Unqualified variables keep the pre-existing intervention-wide match by name: with no session
  # variable to key on there is nothing better to attribute them to.
  def bare_var_names
    @bare_var_names ||= missing_vars.reject { |variable| variable.include?('.') }
  end

  def owning_question_ids
    @owning_question_ids ||= intervention_questions.select { |question| owns_missing_variable?(question) }.map(&:id)
  end

  # `preload` because ownership is decided per question against its OWN session variable.
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

  def answered_question_ids
    latest_user_session_ids = user_session.user_intervention.latest_user_sessions.map(&:id)

    Answer.confirmed
          .where(user_session_id: latest_user_session_ids, question_id: owning_question_ids)
          .pluck(:question_id).uniq
  end
end
