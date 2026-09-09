# frozen_string_literal: true

# CIAS-4191 - the "Set 2" truth table of the workspace document
# `.claude/jira-tasks/cias-4191-dashboard-formula-skip-handling/flow-analysis.html`, run as
# specs. Six participants x three chart configurations = 18 outcome cells, driven from
# `spec/fixtures/chart_statistics/multiple_choice_validity_set.yml` so the document and
# this spec can be diffed against each other instead of drifting.
#
# WHAT ONLY THIS FILE COVERS
#   Every checkbox option of a Multiple-choice question is its OWN formula variable, and
#   only a CHECKED box counts as answered. That is why this formula has 13 variables
#   (3 Singles + 2 Multiples x 5 options) and why Ivy - who answers all five questions -
#   still counts 5 of 13. Nothing else in the suite exercises a Multiple-choice question
#   against the validity gate: `validity_evaluator_spec` hands the evaluator a var-values
#   Hash directly, and the QA harness in `.claude/cias-api/testing/` uses a 9-variable
#   all-Single formula. Here the var values are produced by REAL `Answer` records through
#   `UserSession#all_var_values`, so the option-to-variable mapping is proven, not assumed.
#
# WHY THIS LAYER
#   Answers are built once per file with `let_it_be` and each cell is one
#   `V1::ChartStatistics::Create.call`, so the whole matrix is seconds. The same matrix at
#   the request layer would not be: `spec/requests/v1/organizations/charts_data/` measures
#   ~50 minutes for 63 examples, and `bar_chart/numeric_spec` ~47s per example from the
#   `chart_statistic` factory cascade. A matrix nobody runs pins nothing.
#
# DELIBERATELY UNCOVERED: the document's "Pie Chart E / today / minimum 0" column.
#   Kate, Leo and Mia currently produce NO chart row at all when
#   `min_answered_variables == 0`, and whether that is correct is an OPEN, UNDECIDED
#   question (raised 2026-09-03): a participant who SKIPS a formula item is charted and
#   scores 0, while one BRANCHED AROUND the same item disappears entirely, and TIMEOUT has
#   had no client ruling on either axis. Pinning those six cells now would certify
#   behaviour that is expected to change - and a spec that certifies a wrong expectation is
#   worse than no spec. The alignment work brings its own rows for that column.

# Builds the records the table describes. Kept out of the example groups so those read the
# way the document's table does.
module MultipleChoiceValiditySet
  extend FactoryBot::Syntax::Methods

  # The document scores its Single questions 0..10.
  SINGLE_OPTIONS = (0..10).map { |value| { 'payload' => value.to_s, 'value' => value.to_s } }.freeze

  # String keys on purpose: `Question#question_variables` reads `body['variable']['name']`
  # off the in-memory record, and a symbol-keyed jsonb attribute is not stringified until
  # it is re-read from the database.
  def self.questions(question_group, definitions)
    definitions.to_h { |definition| [definition.fetch('id'), question(question_group, definition)] }
  end

  def self.question(question_group, definition)
    return single_question(question_group, definition) if definition.fetch('type') == 'single'

    multiple_question(question_group, definition)
  end

  def self.single_question(question_group, definition)
    create(:question_single, image: nil, question_group: question_group,
                             body: { 'data' => SINGLE_OPTIONS,
                                     'variable' => { 'name' => definition.fetch('variable') } })
  end

  # One `variable` per option - this is the rule the whole table exists to explain.
  def self.multiple_question(question_group, definition)
    options = definition.fetch('options').map do |option|
      { 'payload' => option.fetch('variable'),
        'variable' => { 'name' => option.fetch('variable'), 'value' => option.fetch('value').to_s } }
    end

    create(:question_multiple, question_group: question_group, body: { 'data' => options })
  end

  # One `Answer` per question the participant actually REACHED. `branched` and `timed_out`
  # leave no row at all; that is their only difference from `skipped`, which leaves a
  # confirmed row carrying a blank `var`. All three are absent from var values.
  def self.answers(user_session, participant, questions)
    participant.fetch('answers').each do |entry|
      next if %w[branched timed_out].include?(entry.fetch('state'))

      question = questions.fetch(entry.fetch('question'))
      create(answer_factory(question), user_session: user_session, question: question,
                                       skipped: entry.fetch('state') == 'skipped',
                                       body: { data: body_data(entry, question) })
    end
  end

  def self.answer_factory(question)
    question.is_a?(Question::Multiple) ? :answer_multiple : :answer_single
  end

  # An UNCHECKED option simply has no body entry, which is why one ticked box in a
  # 5-option Multiple contributes exactly one answered variable rather than five.
  def self.body_data(entry, question)
    return [{ var: '', value: '' }] if entry.fetch('state') == 'skipped'
    return [{ var: question.body['variable']['name'], value: entry.fetch('value').to_s }] unless question.is_a?(Question::Multiple)

    option_values = question.body['data'].to_h { |option| [option['variable']['name'], option['variable']['value']] }
    entry.fetch('checked').map { |variable| { var: variable, value: option_values.fetch(variable) } }
  end
end

fixture = YAML.load_file(Rails.root.join('spec/fixtures/chart_statistics/multiple_choice_validity_set.yml'))
declared_variables = fixture.fetch('questions').flat_map do |definition|
  next [definition.fetch('variable')] if definition.fetch('type') == 'single'

  definition.fetch('options').map { |option| option.fetch('variable') }
end

RSpec.describe V1::ChartStatistics::Create do
  subject(:create_chart_statistic) { described_class.call(chart, user_session, organization) }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:health_system) { create(:health_system, organization: organization) }
  let_it_be(:health_clinic) { create(:health_clinic, health_system: health_system) }
  let_it_be(:dashboard_section) do
    create(:dashboard_section, reporting_dashboard: create(:reporting_dashboard, organization: organization))
  end
  let_it_be(:intervention) { create(:intervention, :published, organization: organization) }
  let_it_be(:session) { create(:session, intervention: intervention, variable: fixture.fetch('session_variable')) }
  let_it_be(:question_group) { create(:question_group, session: session) }
  let_it_be(:questions) { MultipleChoiceValiditySet.questions(question_group, fixture.fetch('questions')) }

  # The document's four columns are four chart configurations; three of them are here.
  let_it_be(:charts) do
    fixture.fetch('chart_configs').to_h do |key, config|
      formula = fixture.fetch('formula').merge(
        'min_answered_variables' => config.fetch('min_answered_variables'),
        'positive_despite_missing_data' => config.fetch('positive_despite_missing_data'),
        'patterns' => config.fetch('patterns') { fixture.fetch('formula').fetch('patterns') }
      )
      [key, create(:chart, dashboard_section: dashboard_section, chart_type: :pie_chart,
                           name: config.fetch('document_name'), formula: formula)]
    end
  end

  # One participant = one user, one user_intervention, one finished user_session and its
  # real answers. Built once for the file; every example only reads them.
  let_it_be(:user_sessions) do
    fixture.fetch('participants').to_h do |participant|
      user = create(:user, :participant, :confirmed)
      user_intervention = create(:user_intervention, user: user, intervention: intervention,
                                                     health_clinic_id: health_clinic.id)
      user_session = create(:user_session, user: user, session: session, user_intervention: user_intervention,
                                           health_clinic: health_clinic, finished_at: DateTime.current)
      MultipleChoiceValiditySet.answers(user_session, participant, questions)
      [participant.fetch('name'), user_session]
    end
  end

  describe 'the formula the table is built on' do
    it "depends on #{fixture.fetch('variable_count')} variables - one per Single question, one per checkbox option" do
      expect(charts.fetch('min_5').formula_variable_count).to eq(fixture.fetch('variable_count'))
      expect(questions.values.flat_map(&:question_variables)).to eq(declared_variables)
    end
  end

  fixture.fetch('participants').each do |participant|
    name = participant.fetch('name')

    describe "#{name} (#{participant.fetch('note')})" do
      let(:user_session) { user_sessions.fetch(name) }
      let(:var_values) { V1::UserInterventionService.new(user_session.user_intervention_id, nil).var_values }

      it "counts #{participant.fetch('answered_variables')} of #{fixture.fetch('variable_count')} answered variables " \
         "and scores #{participant.fetch('score')}" do
        validity = V1::ChartStatistics::ValidityEvaluator.call(charts.fetch('min_5'), var_values)

        expect(validity.variable_count).to eq(fixture.fetch('variable_count'))
        expect(validity.answered_count).to eq(participant.fetch('answered_variables'))
        expect(score_of(charts.fetch('min_5'), var_values)).to eq(participant.fetch('score'))
      end

      # Only where the row count is the point: "answered the question" and "answered its
      # variables" are different facts, and a participant can have five of the first and
      # three of the second.
      if participant['answer_rows']
        it "leaves #{participant.fetch('answer_rows')} answer rows for 5 questions" do
          expect(Answer.where(user_session: user_session).count).to eq(participant.fetch('answer_rows'))
        end
      end

      participant.fetch('outcomes').each do |config_key, outcome|
        config = fixture.fetch('chart_configs').fetch(config_key)
        charted = outcome.fetch('charted', true)
        label = outcome['label']
        expectation = if !charted
                        'produces no chart row at all'
                      elsif outcome.fetch('rescued')
                        "is rescued by the case match into '#{label}'"
                      else
                        "is charted as '#{label}'"
                      end

        context "on #{config.fetch('document_name')} - #{config.fetch('description')}" do
          let(:chart) { charts.fetch(config_key) }

          # The no-row branch asserts the label set as well as the count: what it guards
          # against is not "no row" but "a row under a REAL category label", so a bare count
          # assertion would report the right failure for the wrong reason.
          it expectation do
            if charted
              expect { create_chart_statistic }.to change(ChartStatistic, :count).by(1)
              expect(ChartStatistic.find_by(chart: chart, user: user_session.user).label).to eq(label)
              expect(validity_of(chart, var_values).rescued).to be(outcome.fetch('rescued'))
            else
              expect { described_class.call(chart, user_session, organization) }.not_to change(ChartStatistic, :count)
              expect(ChartStatistic.where(chart: chart, user: user_session.user)).to be_empty
              expect(validity_of(chart, var_values).rescued).to be(false)
            end
          end
        end
      end
    end
  end

  # `Create` keeps the score and the matched pattern private, so re-derive them exactly the
  # way it does. `raw_result` is the 0-filled value the payload evaluated to (the
  # document's Score column) and the matched pattern Hash - or nil when the score fell to
  # the default category - is the only thing the rescue is allowed to look at.
  def evaluate(chart, var_values)
    service = chart.dentaku_service(var_values, chart.formula['payload'], chart.formula['patterns'])
    matched_pattern = chart.calculate(service)

    [service.raw_result, matched_pattern]
  end

  def score_of(chart, var_values)
    evaluate(chart, var_values).first
  end

  def validity_of(chart, var_values)
    score, matched_pattern = evaluate(chart, var_values)

    V1::ChartStatistics::ValidityEvaluator.call(chart, var_values, score, matched_pattern: matched_pattern)
  end
end
