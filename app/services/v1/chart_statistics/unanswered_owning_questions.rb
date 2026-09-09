# frozen_string_literal: true

# Answers "which of the questions that OWN `missing_vars` did the participant actually
# reach?" for `V1::ChartStatistics::Create`, on charts WITHOUT the validity gate
# (`min_answered_variables == 0`). An explicit minimum supersedes both predicates below,
# because the chart owner has then declared how many answers are enough and the remaining
# variables 0-fill.
#
# "Reached" means the owning question has a confirmed `Answer` row - NOT that its variable
# is present in var values. The distinction is the whole point of this class:
# `Answer.confirmed` is `where(draft: false)` and nothing else (answer.rb:17), so a SKIP
# leaves a confirmed row whose body entry has a blank `var`, while a BRANCH-AROUND leaves no
# row at all. Both are absent from `all_var_values` (user_session.rb:24 skips a blank `var`)
# and so both read as "missing" to Dentaku - but only the skip proves the participant stood
# in front of the question.
#
# TWO predicates, and the caller uses `none_answered?`:
#
#   none_answered?  - true when NONE of the owning questions has a confirmed answer, i.e.
#                     the participant never reached this instrument at all. This is the live
#                     ungated rule (client-confirmed 2026-09-03): a participant branched
#                     around, timed out of, or abandoning SOME of a formula's questions is
#                     charted with those variables contributing 0 and lands in an ordinary
#                     Matched / Not-matched category. Only the zero-answered participant is
#                     dropped, which also keeps the cross-session over-counting job the old
#                     strict guard was doing (a participant who finished session B answered
#                     none of a session-A chart's questions).
#
#   call            - true when AT LEAST ONE owning question is unanswered. The strict
#                     legacy rule, shipped May 2026 and retired from the ungated path on
#                     2026-09-04. RETAINED, and currently UNUSED by production code, so the
#                     gated path can adopt it without re-deriving it; it is covered by
#                     `spec/services/v1/chart_statistics/unanswered_owning_questions_spec.rb`.
#                     Do not call it from the ungated path - it drops the branched-around
#                     participant this feature exists to admit.
#
# Both keep `return false if owning_question_ids.empty?` DELIBERATELY. When no question in
# the intervention owns any missing variable there is nothing to measure, so neither
# predicate may claim the participant is absent. It is also what a pre-existing
# cross-intervention hole rides on: two interventions in one organization sharing a bare
# question-variable name (routine after a clone) let a participant of intervention B reach
# this class with `owning_question_ids == []` on intervention A's chart. That hole is
# NARROWED - not closed - from the other side by `CreateForUserSession`'s session
# pre-filter: the pre-filter only bites when the two interventions' session variables
# differ, which a SESSION clone guarantees (`clone_jobs/session.rb:15` renames it) but a
# whole-INTERVENTION clone does not (session variables are copied verbatim). `summary.md`
# has the accurate framing - this job is "closed only halfway". Leaving the bail-out open
# here is a recorded trade-off, not an oversight.
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

  # A chart formula qualifies every variable with its session variable ("s5551_c.q4"), and two
  # sessions of ONE intervention may legitimately carry the same question variable: copying a
  # session renames the session variable (`clone_jobs/session.rb:15`) but never the question
  # variables inside it. Attributing a missing variable by bare name therefore also pulls in the
  # untouched twin in the copied session - which the participant never opened - and reports it as
  # unanswered. Match the pair instead.
  #
  # Under the strict `call` that mis-attribution silently dropped the participant from every
  # ungated chart. Under `none_answered?` it is milder but still wrong: the twin only ever
  # ENLARGES `owning_question_ids`, so it cannot by itself make a participant look absent -
  # but it does decide whether `owning_question_ids` is empty, which is the one place both
  # predicates bail out.
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

  # Scoped to the participant's LATEST fill of each session, because a chart formula can
  # reference variables across several sessions of one intervention.
  #
  # `.map(&:id)`, never `.pluck(:id)`: `latest_user_sessions` is
  # `select('DISTINCT ON("session_id") *').order(:session_id, created_at: :desc, id: :desc)`
  # (user_intervention.rb:20-22), and `pluck` REPLACES `select_values`, destroying the
  # `DISTINCT ON` that defines the relation - a multiple-fill retake would then contribute
  # its older fill's answers as well.
  def answered_question_ids
    latest_user_session_ids = user_session.user_intervention.latest_user_sessions.map(&:id)

    Answer.confirmed
          .where(user_session_id: latest_user_session_ids, question_id: owning_question_ids)
          .pluck(:question_id).uniq
  end
end
