# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::Create do
  subject { described_class.call(chart, user_session, organization) }

  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let(:health_system) { create(:health_system, organization: organization) }
  let(:health_clinic) { create(:health_clinic, health_system: health_system) }

  let(:intervention) { create(:intervention, :published, organization: organization) }
  let(:session) { create(:session, intervention: intervention, variable: 'session_var') }
  let(:user_session) { create(:user_session, user: user, session: session, health_clinic: health_clinic, finished_at: user_session_finished_at) }

  let(:admin) { create(:user, :admin, :confirmed) }
  let(:user) { create(:user, :participant, :confirmed) }

  let(:filled_at) { DateTime.current }
  let(:chart) do
    create(:chart, formula: formula, dashboard_section: dashboard_section, status: 'published', chart_type: :pie_chart,
                   published_at: DateTime.now, date_range_start: DateTime.yesterday, date_range_end: DateTime.tomorrow)
  end
  let(:formula) do
    { 'payload' => 'session_var.fruit',
      'patterns' => [
        {
          'match' => '=1',
          'label' => 'Apple',
          'color' => '#C766EA'
        }
      ],
      'default_pattern' => {
        'label' => 'Banana',
        'color' => '#E2B1F4'
      } }
  end

  let!(:answer) { create(:answer_single, user_session: user_session, body: { data: [{ var: 'fruit', value: '1' }] }) }

  context "when the user session was finished within the chart's data range" do
    let(:user_session_finished_at) { DateTime.now }

    it 'creates a new chart statistic' do
      expect { subject }.to change(ChartStatistic, :count).by(1)
    end
  end

  context 'when the user session was finished near the end of the day in date_range_end' do
    let(:user_session_finished_at) { chart.date_range_end + 24.hours - 1.second }

    it 'creates a new chart statistic' do
      expect { subject }.to change(ChartStatistic, :count).by(1)
    end
  end

  context 'when the user session was finished just after the end of the day in date_range_end' do
    let(:user_session_finished_at) { chart.date_range_end + 24.hours + 1.second }

    it 'creates a new chart statistic' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  context "when the user session was finished before the chart's data range" do
    let(:user_session_finished_at) { DateTime.now - 1.week }

    it 'does not create a new chart statistic' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  context "when the user session was finished after the chart's data range" do
    let(:user_session_finished_at) { DateTime.now + 1.week }

    it 'does not create a new chart statistic' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  describe 'missing variables validation' do
    let(:user_session_finished_at) { DateTime.now }
    let(:question_group) { create(:question_group, session: session) }

    context 'when formula references variables that exist in intervention questions' do
      let!(:question) do
        create(:question_single, question_group: question_group, body: {
                 data: [
                   { payload: 'Apple', value: '1' },
                   { payload: 'Banana', value: '2' }
                 ],
                 variable: { name: 'fruit' }
               })
      end

      let(:formula) do
        {
          'payload' => 'session_var.fruit',
          'patterns' => [{ 'match' => '=1', 'label' => 'Apple', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Other', 'color' => '#E2B1F4' }
        }
      end

      it 'creates chart statistic successfully' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
      end
    end

    context 'when formula references variables from unselected multiple choice options' do
      let!(:multiple_question) do
        create(:question_multiple, question_group: question_group, body: {
                 data: [
                   { payload: 'Option 1', variable: { name: 'option_1', value: '' } },
                   { payload: 'Option 2', variable: { name: 'option_2', value: '' } },
                   { payload: 'Option 3', variable: { name: 'option_3', value: '' } }
                 ]
               })
      end

      # User only selected option_1, but formula references all options
      let!(:answer_multi) do
        create(:answer_multiple, user_session: user_session, question: multiple_question,
                                 body: { data: [{ var: 'option_1', value: '1' }] })
      end

      let(:formula) do
        {
          'payload' => 'session_var.option_1 + session_var.option_2 + session_var.option_3',
          'patterns' => [{ 'match' => '>2', 'label' => 'High', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' }
        }
      end

      it 'logs missing variables from unselected options' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(/missing variables from unselected options/)
      end

      it 'creates chart statistic successfully with missing vars set to 0' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
      end
    end

    context 'when formula references variables that do not exist in any intervention question' do
      let(:formula) do
        {
          'payload' => 'session_var.nonexistent_var + session_var.another_invalid',
          'patterns' => [{ 'match' => '>5', 'label' => 'High', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' }
        }
      end

      it 'does not create chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs error with invalid variable names' do
        allow(Rails.logger).to receive(:error)
        subject
        expect(Rails.logger).to have_received(:error).with(
          /ChartStatistics::Create SKIPPED chart_id=#{chart.id}.*invalid_variables=/
        )
      end

      it 'returns early without processing' do
        expect(ChartStatistic).not_to receive(:find_or_initialize_by)
        subject
      end
    end

    context 'when formula references a mix of valid and invalid variables' do
      let!(:question) do
        create(:question_number, question_group: question_group, body: {
                 data: [{ payload: '' }],
                 variable: { name: 'age' }
               })
      end

      let(:formula) do
        {
          'payload' => 'session_var.age + session_var.invalid_var',
          'patterns' => [{ 'match' => '>18', 'label' => 'Adult', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Minor', 'color' => '#E2B1F4' }
        }
      end

      it 'does not create chart statistic due to invalid variables' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs only the invalid variables' do
        allow(Rails.logger).to receive(:error)
        subject
        expect(Rails.logger).to have_received(:error).with(
          /invalid_variables=\["session_var.invalid_var"\]/
        )
      end
    end

    context 'when formula uses multiple question variables from different question types' do
      let!(:single_question) do
        create(:question_single, question_group: question_group, body: {
                 data: [
                   { payload: 'Yes', value: '1' },
                   { payload: 'No', value: '0' }
                 ],
                 variable: { name: 'consent' }
               })
      end

      let!(:number_question) do
        create(:question_number, question_group: question_group, body: {
                 data: [{ payload: '' }],
                 variable: { name: 'score' }
               })
      end

      let!(:answer_consent) { create(:answer_single, user_session: user_session, body: { data: [{ var: 'consent', value: '1' }] }) }
      let!(:answer_score) { create(:answer_number, user_session: user_session, body: { data: [{ var: 'score', value: '85' }] }) }

      let(:formula) do
        {
          'payload' => 'IF(session_var.consent = 1, session_var.score, 0)',
          'patterns' => [
            { 'match' => '>80', 'label' => 'High Score', 'color' => '#C766EA' },
            { 'match' => '>50', 'label' => 'Medium Score', 'color' => '#F4D03F' }
          ],
          'default_pattern' => { 'label' => 'Low Score', 'color' => '#E2B1F4' }
        }
      end

      it 'creates chart statistic with valid variables from multiple questions' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
      end
    end

    context 'when formula references grid question variables' do
      let!(:grid_question) do
        create(:question_grid, question_group: question_group, body: {
                 data: [
                   {
                     payload: {
                       rows: [
                         { payload: 'Row 1', variable: { name: 'row1' } },
                         { payload: 'Row 2', variable: { name: 'row2' } }
                       ],
                       columns: [
                         { payload: 'Column 1', variable: { value: '1' } },
                         { payload: 'Column 2', variable: { value: '2' } }
                       ]
                     }
                   }
                 ]
               })
      end

      # User reached the grid question and answered both rows; the answer must
      # be tied to grid_question so the new owning-question guard sees it as answered.
      let!(:answer_grid) do
        create(:answer_grid, user_session: user_session, question: grid_question,
                             body: { data: [{ var: 'row1', value: '3' }, { var: 'row2', value: '4' }] })
      end

      let(:formula) do
        {
          'payload' => 'session_var.row1 + session_var.row2',
          'patterns' => [{ 'match' => '>5', 'label' => 'High', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' }
        }
      end

      it 'validates grid variables correctly' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
      end
    end

    context 'when no missing variables exist' do
      let!(:question) do
        create(:question_number, question_group: question_group, body: {
                 data: [{ payload: '' }],
                 variable: { name: 'fruit' }
               })
      end

      let!(:answer) { create(:answer_number, user_session: user_session, body: { data: [{ var: 'fruit', value: '5' }] }) }

      let(:formula) do
        {
          'payload' => 'session_var.fruit',
          'patterns' => [{ 'match' => '=5', 'label' => 'Five', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Other', 'color' => '#E2B1F4' }
        }
      end

      it 'creates chart statistic without validation logic' do
        expect(chart).not_to receive(:validate_formula_variables)
        expect { subject }.to change(ChartStatistic, :count).by(1)
      end
    end

    # Retitled, not inverted. This fixture answers `terms` - which the formula does NOT
    # reference - and none of `epds1..3`, so it always was the ZERO-ANSWERED shape ("Noah"),
    # and the zero-answered rule keeps dropping it. The partial-completion context below is
    # the one that inverts.
    context 'when the user answered none of the questions referenced by formula (never reached the instrument)' do
      # Simulates: user declined a gating question (e.g. terms) and branched
      # straight to Finish, never reaching the EPDS-style screening questions.
      let!(:terms_question) do
        create(:question_single, question_group: question_group, body: {
                 data: [{ payload: 'Yes', value: '1' }],
                 variable: { name: 'terms' }
               })
      end

      let!(:terms_answer) do
        create(:answer_single, user_session: user_session, question: terms_question,
                               body: { data: [{ var: 'terms', value: '1' }] })
      end

      let!(:epds_questions) do
        (1..3).map do |i|
          create(:question_single, question_group: question_group, body: {
                   data: [{ payload: 'Yes', value: '1' }],
                   variable: { name: "epds#{i}" }
                 })
        end
      end

      let(:formula) do
        {
          'payload' => 'session_var.epds1 + session_var.epds2 + session_var.epds3',
          'patterns' => [{ 'match' => '>=2', 'label' => 'Positive', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' }
        }
      end

      it 'does not create chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the skip with the answered-none message' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end

    # INVERTED 2026-09-04. Partial completion used to be dropped by the strict guard; on an
    # ungated chart the participant is now charted and `epds3` contributes 0.
    context 'when user reached only some of the referenced questions (partial completion)' do
      let!(:epds_questions) do
        (1..3).map do |i|
          create(:question_single, question_group: question_group, body: {
                   data: [{ payload: 'Yes', value: '1' }],
                   variable: { name: "epds#{i}" }
                 })
        end
      end

      let!(:partial_answers) do
        epds_questions.first(2).map do |q|
          create(:answer_single, user_session: user_session, question: q,
                                 body: { data: [{ var: q.body['variable']['name'], value: '1' }] })
        end
      end

      let(:formula) do
        {
          'payload' => 'session_var.epds1 + session_var.epds2 + session_var.epds3',
          'patterns' => [{ 'match' => '>=2', 'label' => 'Positive', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' }
        }
      end

      it 'creates a chart statistic labelled by the 0-filled score' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        # 1 + 1 + 0 => 2, which matches the '>=2' case.
        expect(ChartStatistic.last.label).to eq('Positive')
      end

      it 'does not log the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end

    # RE-ANCHORED 2026-09-04. This context used to prove the qualified-pair ownership lookup
    # by answering `epds1` and skipping `epds2`; under the zero-answered rule one PRESENT
    # variable short-circuits the whole predicate, so the ownership lookup was never reached
    # and the example became vacuous. Both questions are now SKIPPED, which puts every
    # formula variable in `missing_vars` and forces the ownership lookup to run - so the
    # context proves two things that matter:
    #
    #   1. A participant who REACHED every chart question and SKIPPED every one is still
    #      charted. This is the no-regression guarantee: a skip leaves a confirmed `Answer`
    #      with a blank `var`, so this participant has ZERO var-values present and would be
    #      newly DROPPED had "answered" been measured on var-values like the gated path does.
    #   2. The twin question in the copied session does not disturb that. Copying a session
    #      renames only the SESSION variable (`clone_jobs/session.rb:15`), never the question
    #      variables inside it, so one intervention legitimately holds two questions named
    #      `epds2`. Pair-vs-bare matching itself is unit-tested in
    #      `spec/services/v1/chart_statistics/unanswered_owning_questions_spec.rb`.
    context 'when the participant skipped every referenced question and another session reuses the same variable' do
      let!(:question_reached) do
        create(:question_single, question_group: question_group, body: {
                 data: [{ payload: 'Yes', value: '1' }],
                 variable: { name: 'epds1' }
               })
      end

      let!(:question_skipped) do
        create(:question_single, question_group: question_group, body: {
                 data: [{ payload: 'Yes', value: '1' }],
                 variable: { name: 'epds2' }
               })
      end

      let(:copied_session) { create(:session, intervention: intervention, variable: 'cloned_session_var_2') }
      let(:copied_question_group) { create(:question_group, session: copied_session) }

      # The twin the participant never opened - same question variable, different session.
      let!(:copied_question) do
        create(:question_single, question_group: copied_question_group, body: {
                 data: [{ payload: 'Yes', value: '1' }],
                 variable: { name: 'epds2' }
               })
      end

      # A skip stores a confirmed answer whose `var` is blank, so neither variable reaches
      # `var_values` and BOTH land in `missing_vars` - but both questions WERE reached.
      let!(:answer_reached) do
        create(:answer_single, user_session: user_session, question: question_reached, skipped: true,
                               body: { data: [{ var: '', value: '' }] })
      end

      let!(:answer_skipped) do
        create(:answer_single, user_session: user_session, question: question_skipped, skipped: true,
                               body: { data: [{ var: '', value: '' }] })
      end

      let(:formula) do
        {
          'payload' => 'session_var.epds1 + session_var.epds2',
          'patterns' => [{ 'match' => '>=1', 'label' => 'Positive', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' }
        }
      end

      it 'creates the chart statistic - a skip counts as reaching the question' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        # Both variables 0-fill, so the score is 0 and no explicit case matches.
        expect(ChartStatistic.last.label).to eq('Negative')
      end

      it 'does not log the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end
  end

  describe 'chart validity gate (min_answered_variables > 0)' do
    let(:user_session_finished_at) { DateTime.now }
    let(:question_group) { create(:question_group, session: session) }
    let(:min_answered_variables) { 7 }
    let(:rescue_enabled) { false }
    let(:answered_variables) { 3 }
    let(:answer_value) { '1' }

    let(:formula) do
      {
        'payload' => (1..9).map { |i| "session_var.epds#{i}" }.join(' + '),
        'patterns' => [{ 'match' => '>=2', 'label' => 'Positive', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
        'min_answered_variables' => min_answered_variables,
        'positive_despite_missing_data' => rescue_enabled
      }
    end

    let!(:epds_questions) do
      (1..9).map do |i|
        create(:question_single, question_group: question_group, body: {
                 data: [{ payload: 'Yes', value: '1' }],
                 variable: { name: "epds#{i}" }
               })
      end
    end

    # Only the first `answered_variables` questions were reached; the rest were
    # branched around and leave no confirmed answer at all.
    let!(:epds_answers) do
      epds_questions.first(answered_variables).each_with_index.map do |question, index|
        create(:answer_single, user_session: user_session, question: question,
                               body: { data: [{ var: "epds#{index + 1}", value: answer_value }] })
      end
    end

    context 'when fewer variables are answered than the minimum' do
      it 'creates one row under the reserved Invalid / Insufficient Data label' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
      end

      it 'logs the classification with the counts, score, rescue flag and match state' do
        allow(Rails.logger).to receive(:info)
        subject
        # score 3 matches the '>=2' case, but the rescue is off — matched=true, rescue_enabled=false.
        expect(Rails.logger).to have_received(:info).with(
          /INSUFFICIENT_DATA chart_id=#{chart.id}.*answered=3 required=7 of=9 score=3 rescue_enabled=false matched=true/
        )
      end
    end

    context 'when the participant answered none of the chart variables' do
      # The participant who reached none of the chart's questions. This branch is
      # LIVE-reachable, not replay-only: here the participant is finishing the very session
      # the formula references and was branched around all nine of its variables. On the
      # replay path the same holds for any referenced session. Until 2026-09-04
      # `CreateForUserSession` ALSO evaluated every non-draft chart in the organization on
      # every session finish with no session filter, which fed this branch a much larger
      # population; its session pre-filter now drops those charts before `Create` runs.
      # Either way they keep today's silent skip rather than surfacing as a visible Invalid
      # slice (client-confirmed `answered_count >= 1` rule).
      let(:answered_variables) { 0 }

      it 'does not create a chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs a premature exclusion, not an Invalid classification' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(/EXCLUDED chart_id=#{chart.id}.*answered=0 required=7/)
        expect(Rails.logger).not_to have_received(:info).with(/INSUFFICIENT_DATA chart_id=#{chart.id}/)
      end

      it 'reaches the gate rather than the ungated zero-answered guard' do
        # The `!validity_gate_enabled?` prefix on the ungated guard is what makes the two
        # paths distinguishable when they agree on the outcome. Drop that prefix and this
        # participant returns from the ungated guard, so no `EXCLUDED` line is ever emitted.
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end

    # The sharp edge between the two definitions of "answered", pinned from the gated side.
    # With the gate ON, `answered` is var-values presence (validity_evaluator.rb:121-122), so
    # a participant who reached every variable and skipped every one counts as 0 answered and
    # is EXCLUDED. With the gate OFF the same participant is CHARTED, because the ungated rule
    # measures the owning question instead - see the "reached every chart question and skipped
    # every one" example in the ungated worked-example block. The asymmetry is deliberate:
    # gated behaviour is shipped and client-confirmed and does not change here.
    context 'when the gate is on and the participant skipped every chart variable' do
      let(:answered_variables) { 0 }

      let!(:skipped_answers) do
        epds_questions.map do |question|
          create(:answer_single, user_session: user_session, question: question, skipped: true,
                                 body: { data: [{ var: '', value: '' }] })
        end
      end

      it 'excludes them, exactly as before' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the gate exclusion, not the ungated answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(/EXCLUDED chart_id=#{chart.id}.*answered=0 required=7/)
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end

    context 'when exactly the minimum is answered' do
      let(:answered_variables) { 7 }

      it 'creates a chart statistic labelled by the 0-filled score' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq('Positive')
      end

      it 'passes the gate silently - no gate-outcome line at all' do
        # Replaced the old "bypasses the never-reached-question guard" assertion, which went
        # vacuous when that guard's log line was retired. A clean pass must emit none of the
        # three gate-outcome lines; a misclassification here would emit one.
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/EXCLUDED chart_id=#{chart.id}/)
        expect(Rails.logger).not_to have_received(:info).with(/INSUFFICIENT_DATA chart_id=#{chart.id}/)
        expect(Rails.logger).not_to have_received(:info).with(/RETAINED chart_id=#{chart.id}/)
      end
    end

    context 'when a skipped answer leaves its variable blank' do
      let(:answered_variables) { 6 }

      let!(:skipped_answer) do
        create(:answer_single, user_session: user_session, question: epds_questions[6], skipped: true,
                               body: { data: [{ var: '', value: '' }] })
      end

      it 'does not count the skipped question towards the minimum' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        # Had the skipped answer counted, answered would have reached the minimum of 7 and
        # the participant would carry a score label instead of the reserved one.
        expect(ChartStatistic.last.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
      end
    end

    context 'when the participant is below the minimum but the 0-filled score matches an explicit case' do
      let(:rescue_enabled) { true }
      let(:answer_value) { '10' }

      it 'rescues the participant with that case\'s label — never the default or reserved label' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq('Positive')
        expect(ChartStatistic.last.label).not_to eq('Negative')
        expect(ChartStatistic.last.label).not_to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
      end
    end

    context 'when the participant is below the minimum and the score falls to the default category' do
      # The structural guarantee survives phase 6: with the rescue ON, a participant whose
      # 0-filled score matches no explicit case is still never labelled by the DEFAULT
      # pattern — they become visible under the reserved label instead.
      let(:rescue_enabled) { true }
      let(:answer_value) { '0' }

      it 'creates a reserved-label row, never a default-labelled one' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
        expect(ChartStatistic.last.label).not_to eq('Negative')
      end
    end

    context 'when the matched case carries the default category label' do
      # The end-to-end half of the guarantee: `Create#label` would otherwise stamp
      # 'Negative' and the pie would render this participant inside the default bucket.
      let(:rescue_enabled) { true }
      let(:answer_value) { '10' }
      let(:formula) do
        {
          'payload' => (1..9).map { |i| "session_var.epds#{i}" }.join(' + '),
          'patterns' => [{ 'match' => '>=2', 'label' => 'Negative', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables,
          'positive_despite_missing_data' => rescue_enabled
        }
      end

      it 'creates a reserved-label row instead of a Negative one' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
        expect(ChartStatistic.last.label).not_to eq('Negative')
      end
    end

    context 'when the rescue is off and the score matches an explicit case' do
      let(:rescue_enabled) { false }
      let(:answer_value) { '10' }

      it 'creates a reserved-label row rather than the matched case label' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
        expect(ChartStatistic.last.label).not_to eq('Positive')
      end
    end

    describe 'per-participant de-duplication' do
      let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention, health_clinic_id: health_clinic.id) }

      let(:session_a) { create(:session, intervention: intervention, variable: 'sa') }
      let(:session_b) { create(:session, intervention: intervention, variable: 'sb') }
      let(:question_group_a) { create(:question_group, session: session_a) }
      let(:question_group_b) { create(:question_group, session: session_b) }

      let!(:question_a) do
        create(:question_number, question_group: question_group_a, body: { data: [{ payload: '' }], variable: { name: 'a' } })
      end
      let!(:question_b) do
        create(:question_number, question_group: question_group_b, body: { data: [{ payload: '' }], variable: { name: 'b' } })
      end

      let(:min_answered_variables) { 1 }
      let(:formula) do
        {
          'payload' => 'sa.a + sb.b',
          'patterns' => [{ 'match' => '>=10', 'label' => 'High', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables,
          'positive_despite_missing_data' => rescue_enabled
        }
      end

      let(:user_session_a) do
        create(:user_session, user: user, session: session_a, user_intervention: user_intervention,
                              health_clinic: health_clinic, finished_at: DateTime.now - 2.hours)
      end
      let(:user_session_b) do
        create(:user_session, user: user, session: session_b, user_intervention: user_intervention,
                              health_clinic: health_clinic, finished_at: DateTime.now - 1.hour)
      end

      let!(:answer_a) do
        create(:answer_number, user_session: user_session_a, question: question_a, body: { data: [{ var: 'a', value: '1' }] })
      end
      # Deliberately lazy: session B must not be filled in before session A finishes.
      let(:answer_b) do
        create(:answer_number, user_session: user_session_b, question: question_b, body: { data: [{ var: 'b', value: '20' }] })
      end

      it 'keeps exactly one row per participant and updates it in place' do
        expect { described_class.call(chart, user_session_a, organization) }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq('Low')

        answer_b
        expect { described_class.call(chart, user_session_b, organization) }.not_to change(ChartStatistic, :count)

        statistic = ChartStatistic.last
        expect(statistic.label).to eq('High')
        expect(statistic.user_session).to eq(user_session_b)
        expect(statistic.filled_at).to be_within(1.second).of(user_session_b.finished_at)
      end

      it 'keeps the later finish when the back-fill processes sessions out of order' do
        answer_b
        described_class.call(chart, user_session_b, organization)
        described_class.call(chart, user_session_a, organization)

        expect(ChartStatistic.count).to eq(1)
        statistic = ChartStatistic.last
        expect(statistic.user_session).to eq(user_session_b)
        expect(statistic.filled_at).to be_within(1.second).of(user_session_b.finished_at)
      end

      it 'never retracts a participant who is already charted' do
        described_class.call(chart, user_session_a, organization)
        statistic = ChartStatistic.last
        expect(statistic.label).to eq('Low')

        # The researcher raises the minimum above M; the back-fill re-runs over the
        # participant's other finished session. The no-downgrade half of the precedence
        # lattice keeps the real label - exclusion never destroys, and never relabels.
        chart.update!(formula: chart.formula.merge('min_answered_variables' => 5))
        answer_b

        expect { described_class.call(chart, user_session_b, organization) }.not_to change(ChartStatistic, :count)
        expect(statistic.reload.label).to eq('Low')
        expect(statistic.label).not_to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
        expect(statistic.user_session).to eq(user_session_a)
      end
    end

    describe 'outcome precedence over back-fill replay order' do
      # `CreateForUserSessions` selects finished sessions by session VARIABLE across the
      # whole organization with NO ORDER BY (create_for_user_sessions.rb:26-32), and
      # `V1::Charts::Regenerate` destroys and replays, so two interventions that both use
      # the session variable this chart references feed the SAME de-dup key (organization,
      # health_system, health_clinic, chart, user) in an arbitrary order - while each call's
      # `answered_count` comes from its own `user_intervention`'s answers, so the outcomes
      # genuinely differ. A real-label outcome must therefore beat a persisted Invalid row
      # regardless of `filled_at`, and an Invalid outcome must never overwrite a real one.
      # One finished session on its own intervention and user_intervention, in the SAME
      # clinic as every other fill so they all collapse onto one de-dup key.
      def fill!(answers, finished_at:)
        other_intervention = create(:intervention, :published, organization: organization)
        other_session = create(:session, intervention: other_intervention, variable: 'sa')
        group = create(:question_group, session: other_session)
        questions = %w[a b].index_with do |name|
          create(:question_number, question_group: group, body: { data: [{ payload: '' }], variable: { name: name } })
        end
        user_intervention = create(:user_intervention, user: user, intervention: other_intervention,
                                                       health_clinic_id: health_clinic.id)
        fill = create(:user_session, user: user, session: other_session, user_intervention: user_intervention,
                                     health_clinic: health_clinic, finished_at: finished_at)
        answers.each do |name, value|
          create(:answer_number, user_session: fill, question: questions[name], body: { data: [{ var: name, value: value }] })
        end
        fill
      end

      let(:min_answered_variables) { 2 }
      let(:formula) do
        {
          'payload' => 'sa.a + sa.b',
          'patterns' => [{ 'match' => '>=10', 'label' => 'High', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables,
          'positive_despite_missing_data' => rescue_enabled
        }
      end
      # Both variables answered -> 2 of 2 -> passes, score 20 -> 'High'. Deliberately the
      # OLDER of the two finishes.
      let(:passing_fill) { fill!({ 'a' => '20', 'b' => '0' }, finished_at: DateTime.now - 2.hours) }
      # Only one variable answered -> 1 of 2, rescue off -> Invalid. The NEWER finish.
      let(:invalid_fill) { fill!({ 'a' => '1' }, finished_at: DateTime.now - 1.hour) }

      it 'upgrades a persisted Invalid row when a passing finish arrives later' do
        described_class.call(chart, invalid_fill, organization)
        expect(ChartStatistic.count).to eq(1)
        expect(ChartStatistic.last.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)

        newer_passing = fill!({ 'a' => '20', 'b' => '0' }, finished_at: DateTime.now)
        expect { described_class.call(chart, newer_passing, organization) }.not_to change(ChartStatistic, :count)
        expect(ChartStatistic.last.label).to eq('High')
      end

      it 'upgrades a persisted Invalid row even when the passing finish is OLDER' do
        # The falsifiable core of the lattice: the passing finish is an hour OLDER than the
        # Invalid one, so a filled_at-only guard would freeze this row at Invalid forever.
        described_class.call(chart, invalid_fill, organization)
        described_class.call(chart, passing_fill, organization)

        expect(ChartStatistic.count).to eq(1)
        statistic = ChartStatistic.last
        expect(statistic.label).to eq('High')
        expect(statistic.user_session).to eq(passing_fill)
        expect(statistic.filled_at).to be_within(1.second).of(passing_fill.finished_at)
      end

      it 'never downgrades a real-label row when the Invalid finish is replayed second' do
        # Together with the example above this is REPLAY-ORDER INVARIANCE: the same two
        # finishes end in the same label, user_session AND filled_at in either order.
        described_class.call(chart, passing_fill, organization)
        expect { described_class.call(chart, invalid_fill, organization) }.not_to change(ChartStatistic, :count)

        statistic = ChartStatistic.last
        expect(statistic.label).to eq('High')
        expect(statistic.user_session).to eq(passing_fill)
        expect(statistic.filled_at).to be_within(1.second).of(passing_fill.finished_at)
      end

      it 'logs the retained row rather than relabelling it' do
        described_class.call(chart, passing_fill, organization)
        allow(Rails.logger).to receive(:info)

        described_class.call(chart, invalid_fill, organization)

        # Deliberately not asserting the persisted label: the line no longer carries it (a
        # participant's clinical category does not belong in a log). Still falsifiable — delete
        # the retain branch and no RETAINED line is emitted at all.
        expect(Rails.logger).to have_received(:info).with(/RETAINED chart_id=#{chart.id}/)
      end

      it 'keeps the newer finish when both outcomes are Invalid' do
        # Within one outcome class the filled_at ordering guard still rules.
        older_invalid = fill!({ 'a' => '1' }, finished_at: DateTime.now - 3.hours)

        described_class.call(chart, invalid_fill, organization)
        described_class.call(chart, older_invalid, organization)

        expect(ChartStatistic.count).to eq(1)
        statistic = ChartStatistic.last
        expect(statistic.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
        expect(statistic.user_session).to eq(invalid_fill)
      end
    end

    describe 'a below-minimum retake' do
      # A same-clinic retake is impossible: `index_user_session_on_u_id_and_s_id_and_hc_id`
      # is unconditionally unique. A multiple-fill retake therefore always lands in a
      # different clinic, and `latest_user_sessions` (DISTINCT ON session_id) makes the
      # newer, thinner fill the one that counts.
      let(:retake_clinic) { create(:health_clinic, health_system: health_system) }
      let(:retake_session) { create(:session, intervention: intervention, variable: 'rt', multiple_fill: true) }
      let(:retake_question_group) { create(:question_group, session: retake_session) }
      let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention, health_clinic_id: health_clinic.id) }

      let!(:retake_questions) do
        %w[r1 r2].map do |name|
          create(:question_number, question_group: retake_question_group, body: { data: [{ payload: '' }], variable: { name: name } })
        end
      end

      let(:min_answered_variables) { 2 }
      let(:formula) do
        {
          'payload' => 'rt.r1 + rt.r2',
          'patterns' => [{ 'match' => '>=2', 'label' => 'Positive', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables
        }
      end

      let(:first_fill) do
        create(:user_session, user: user, session: retake_session, user_intervention: user_intervention, multiple_fill: true,
                              health_clinic: health_clinic, finished_at: DateTime.now - 2.hours, created_at: DateTime.now - 3.hours)
      end
      let(:retake_fill) do
        create(:user_session, user: user, session: retake_session, user_intervention: user_intervention, multiple_fill: true,
                              health_clinic: retake_clinic, finished_at: DateTime.now - 1.hour, created_at: DateTime.now - 1.hour)
      end

      let!(:first_fill_answers) do
        retake_questions.each_with_index.map do |question, index|
          create(:answer_number, user_session: first_fill, question: question,
                                 body: { data: [{ var: "r#{index + 1}", value: '1' }] })
        end
      end

      # The retake replaces the earlier answers in var values, so this participant
      # drops below the minimum. Deliberately lazy - it must not exist before the first finish.
      let(:retake_answer) do
        create(:answer_number, user_session: retake_fill, question: retake_questions.first,
                               body: { data: [{ var: 'r1', value: '1' }] })
      end

      it 'retains the row the earlier fill created' do
        described_class.call(chart, first_fill, organization)
        statistic = ChartStatistic.last
        expect(statistic.label).to eq('Positive')

        retake_answer
        described_class.call(chart, retake_fill, organization)

        statistic.reload
        expect(statistic.label).to eq('Positive')
        expect(statistic.user_session).to eq(first_fill)
        expect(statistic.health_clinic).to eq(health_clinic)
      end

      it 'records the sibling-clinic retake as its own Invalid row' do
        # `health_clinic` stays in the de-dup key, so a multiple-fill retake (which can only
        # land in a DIFFERENT clinic - the user/session/clinic index is unconditionally
        # unique) is a separate participant-clinic cell. Before phase 6 that cell produced
        # nothing; now the below-minimum retake is visible there, while clinic A keeps its
        # real label. Clinic filtering is how the dashboard reads these apart.
        described_class.call(chart, first_fill, organization)
        retake_answer

        expect { described_class.call(chart, retake_fill, organization) }.to change(ChartStatistic, :count).by(1)

        retake_row = ChartStatistic.find_by(health_clinic: retake_clinic, chart: chart, user: user)
        expect(retake_row.label).to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
        expect(retake_row.user_session).to eq(retake_fill)
      end
    end
  end

  # The canonical worked example from
  # .claude/jira-tasks/feature-ungated-chart-branched-participant-inclusion/feature.md -
  # "Pie Chart A": q1..q4, Matched cutoff 20, NO minimum set (`min_answered_variables` absent,
  # which is every chart in production). One example per row of that table.
  #
  #   | Participant | Answers                 | Score | Chart A before | Chart A after   |
  #   |-------------|-------------------------|-------|----------------|-----------------|
  #   | Anna        | 4 of 4                  |  26   | Matched        | Matched         |
  #   | Ben         | 4 of 4                  |  10   | Not matched    | Not matched     |
  #   | Carol       | 3 of 4 - q4 skipped     |  24   | Matched        | Matched         |
  #   | Dan         | 2 of 4 - q3,q4 branched |  20   | no row         | Matched         |
  #   | Filip       | 2 of 4 - q3,q4 branched |  14   | no row         | Not matched     |
  #   | Grace       | 3 of 4 - q4 timed out   |  21   | no row         | Matched         |
  #   | Eve         | 1 of 4 - q2..q4 skipped |   4   | Not matched    | Not matched     |
  #   | Noah        | 0 of 4 - never reached  |   0   | no row         | no row          |
  #
  # Carol and Eve are the no-regression guarantee; Dan, Filip and Grace are the change; Noah
  # is what still keeps the guard's second job alive.
  describe 'ungated chart alignment - feature.md "Pie Chart A" worked example' do
    let(:user_session_finished_at) { DateTime.now }
    let(:question_group) { create(:question_group, session: session) }

    let(:formula) do
      {
        'payload' => (1..4).map { |i| "session_var.q#{i}" }.join(' + '),
        'patterns' => [{ 'match' => '>=20', 'label' => 'Matched', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'Not matched', 'color' => '#E2B1F4' }
      }
    end

    let!(:chart_questions) do
      (1..4).map do |i|
        create(:question_number, question_group: question_group,
                                 body: { data: [{ payload: '' }], variable: { name: "q#{i}" } })
      end
    end

    # `answered` maps a 1-based question index to its value. `skipped` lists indexes the
    # participant REACHED and skipped - a confirmed answer whose body entry has a blank `var`.
    # Any index in neither list was branched around, timed out of, or abandoned: all three are
    # byte-identical in the data (no "was branched" marker is persisted anywhere), which is
    # why one rule necessarily covers all of them.
    def fill!(answered: {}, skipped: [])
      answered.each do |index, value|
        create(:answer_number, user_session: user_session, question: chart_questions[index - 1],
                               body: { data: [{ var: "q#{index}", value: value }] })
      end
      skipped.each do |index|
        create(:answer_number, user_session: user_session, question: chart_questions[index - 1],
                               skipped: true, body: { data: [{ var: '', value: '' }] })
      end
    end

    def chart_row
      ChartStatistic.find_by(chart: chart, user: user)
    end

    context 'Anna - answered all four, score 26' do
      before { fill!(answered: { 1 => '10', 2 => '8', 3 => '5', 4 => '3' }) }

      it 'is charted as Matched, unchanged' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Matched')
      end
    end

    context 'Ben - answered all four, score 10' do
      before { fill!(answered: { 1 => '4', 2 => '3', 3 => '2', 4 => '1' }) }

      it 'is charted as Not matched, unchanged' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Not matched')
      end
    end

    context 'Carol - reached all four, skipped q4, score 24' do
      before { fill!(answered: { 1 => '10', 2 => '8', 3 => '6' }, skipped: [4]) }

      it 'is charted as Matched - MUST NOT CHANGE' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Matched')
      end
    end

    context 'Eve - reached all four, skipped q2..q4, score 4' do
      before { fill!(answered: { 1 => '4' }, skipped: [2, 3, 4]) }

      it 'is charted as Not matched - MUST NOT CHANGE' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Not matched')
      end
    end

    context 'Dan - branched around q3 and q4, score 20' do
      before { fill!(answered: { 1 => '12', 2 => '8' }) }

      it 'is now charted as Matched instead of being dropped' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Matched')
      end

      it 'does not log the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end

    context 'Filip - branched around q3 and q4, score 14' do
      before { fill!(answered: { 1 => '8', 2 => '6' }) }

      # ACCEPTED CONSEQUENCE, client-confirmed (feature.md decision 1): ordinary labels only
      # on ungated charts, so Filip is published as a confident 'Not matched' from 2-of-4
      # data. There is no Invalid / Insufficient Data category when the gate is off. Pinned
      # deliberately so nobody "fixes" it into an Invalid row.
      it 'is charted as Not matched, not as an Invalid row' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Not matched')
        expect(chart_row.label).not_to eq(ChartStatistic::INSUFFICIENT_DATA_LABEL)
      end
    end

    context 'Grace - timed out of q4, score 21' do
      before { fill!(answered: { 1 => '10', 2 => '8', 3 => '3' }) }

      # A timeout is indistinguishable from a branch-around in the data, so Grace comes along
      # with Dan whether or not anyone asked for her. Stated as a scope fact, not an accident.
      it 'is now charted as Matched - a timeout is indistinguishable from a branch-around' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Matched')
      end
    end

    context 'Noah - never reached the instrument, answered none of the four' do
      it 'still produces no row' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(
          /SKIPPED chart_id=#{chart.id}.*answered NONE of the questions referenced by formula/
        )
      end
    end

    # THE no-regression example. A participant who reached every chart question and skipped
    # every one has ZERO of the formula's variables present in var values, so measuring
    # "answered" on var-values presence - the way the gated path does
    # (validity_evaluator.rb:121-122) - would newly DROP them. They are charted today, and the
    # client required that population not change. The rule therefore measures the OWNING
    # QUESTION having a confirmed `Answer`, which a skip provides and a branch-around does not.
    context 'when the participant reached every chart question and skipped every one' do
      before { fill!(skipped: [1, 2, 3, 4]) }

      it 'is still charted' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Not matched')
      end

      it 'does not log the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end

    # THE example that separates `none_answered?` from the retired strict `call`. Every other
    # newly-admitted participant here (Dan, Filip, Grace) has at least one variable PRESENT in
    # var values and is admitted by that cheap check alone - the strict rule would have
    # admitted them too, had it ever been reached. This participant has NO variable present
    # (the skip contributes none) and yet reached one question, so the two predicates disagree:
    # strict drops them, zero-answered charts them. Score 0, ordinary Not matched.
    context 'when the participant skipped one question and was branched around the rest' do
      before { fill!(skipped: [1]) }

      it 'is charted - one reached question is enough' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(chart_row.label).to eq('Not matched')
      end

      it 'does not log the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/answered NONE of the questions referenced by formula/)
      end
    end
  end

  # The guard's SECOND job, which the zero-answered rule has to keep doing. `CreateForUserSession`
  # used to select every non-draft chart in the ORGANIZATION with no session filter, and
  # `Chart#validate_formula_variables` matches bare variable names intervention-wide, so this
  # service is reachable with a chart whose formula belongs to a session the participant never
  # opened. WI-17's pre-filter now drops most of those earlier, but the replay path and
  # `Create`'s direct callers still depend on this backstop.
  describe 'a cross-session participant on a single-session-formula chart' do
    subject { described_class.call(chart, followup_user_session, organization) }

    let(:user_session_finished_at) { DateTime.now }
    let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention, health_clinic_id: health_clinic.id) }

    let(:screening_session) { create(:session, intervention: intervention, variable: 'ht1') }
    let(:screening_group) { create(:question_group, session: screening_session) }
    let(:followup_session) { create(:session, intervention: intervention, variable: 'ht2') }
    let(:followup_group) { create(:question_group, session: followup_session) }

    let!(:screening_questions) do
      (1..2).map do |i|
        create(:question_number, question_group: screening_group,
                                 body: { data: [{ payload: '' }], variable: { name: "s#{i}" } })
      end
    end
    let!(:followup_question) do
      create(:question_number, question_group: followup_group,
                               body: { data: [{ payload: '' }], variable: { name: 'f1' } })
    end

    # Scoped to the screening session only.
    let(:formula) do
      {
        'payload' => 'ht1.s1 + ht1.s2',
        'patterns' => [{ 'match' => '>=1', 'label' => 'Matched', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'Not matched', 'color' => '#E2B1F4' }
      }
    end

    # The participant only ever opened the follow-up session.
    let(:followup_user_session) do
      create(:user_session, user: user, session: followup_session, user_intervention: user_intervention,
                            health_clinic: health_clinic, finished_at: DateTime.now)
    end
    let!(:followup_answer) do
      create(:answer_number, user_session: followup_user_session, question: followup_question,
                             body: { data: [{ var: 'f1', value: '9' }] })
    end

    it 'produces no all-zeros row' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end

    it 'logs the answered-none skip' do
      allow(Rails.logger).to receive(:info)
      subject
      expect(Rails.logger).to have_received(:info).with(
        /SKIPPED chart_id=#{chart.id}.*answered NONE of the questions referenced by formula/
      )
    end
  end

  # WI-14. The ungated key used to carry `label` and `user_session` while the score has always
  # been computed from the WHOLE `user_intervention`, so a participant gained an extra row at
  # every later session finish and was counted once per finish in the population. The key is
  # now the same de-duplicated one the gated path already used.
  describe 'per-participant de-duplication on an ungated chart' do
    let(:user_session_finished_at) { DateTime.now }
    let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention, health_clinic_id: health_clinic.id) }

    let(:session_a) { create(:session, intervention: intervention, variable: 'sa') }
    let(:session_b) { create(:session, intervention: intervention, variable: 'sb') }
    let(:question_group_a) { create(:question_group, session: session_a) }
    let(:question_group_b) { create(:question_group, session: session_b) }

    let!(:question_a) do
      create(:question_number, question_group: question_group_a, body: { data: [{ payload: '' }], variable: { name: 'a' } })
    end
    let!(:question_b) do
      create(:question_number, question_group: question_group_b, body: { data: [{ payload: '' }], variable: { name: 'b' } })
    end

    # No `min_answered_variables` key at all - the gate is off, as on every production chart.
    let(:formula) do
      {
        'payload' => 'sa.a + sb.b',
        'patterns' => [{ 'match' => '>=10', 'label' => 'High', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' }
      }
    end

    let(:user_session_a) do
      create(:user_session, user: user, session: session_a, user_intervention: user_intervention,
                            health_clinic: health_clinic, finished_at: DateTime.now - 2.hours)
    end
    let(:user_session_b) do
      create(:user_session, user: user, session: session_b, user_intervention: user_intervention,
                            health_clinic: health_clinic, finished_at: DateTime.now - 1.hour)
    end

    let!(:answer_a) do
      create(:answer_number, user_session: user_session_a, question: question_a, body: { data: [{ var: 'a', value: '1' }] })
    end
    # Deliberately lazy: session B must not be filled in before session A finishes.
    let(:answer_b) do
      create(:answer_number, user_session: user_session_b, question: question_b, body: { data: [{ var: 'b', value: '20' }] })
    end

    it 'keeps exactly one row across two finishes in the same intervention' do
      # Finishing A charts the participant on partial data (that is the alignment change:
      # `sb.b` is missing and 0-fills instead of dropping them).
      expect { described_class.call(chart, user_session_a, organization) }.to change(ChartStatistic, :count).by(1)
      expect(ChartStatistic.last.label).to eq('Low')

      answer_b
      expect { described_class.call(chart, user_session_b, organization) }.not_to change(ChartStatistic, :count)

      statistic = ChartStatistic.last
      expect(statistic.label).to eq('High')
      expect(statistic.user_session).to eq(user_session_b)
      expect(statistic.filled_at).to be_within(1.second).of(user_session_b.finished_at)
    end

    it 'lets the latest finish win when the back-fill replays sessions out of order' do
      answer_b
      described_class.call(chart, user_session_b, organization)
      described_class.call(chart, user_session_a, organization)

      expect(ChartStatistic.count).to eq(1)
      statistic = ChartStatistic.last
      expect(statistic.user_session).to eq(user_session_b)
      expect(statistic.filled_at).to be_within(1.second).of(user_session_b.finished_at)
    end

    # The HT1/HT2/HT3 shape the developer reproduced by hand, and the one the client message
    # describes: a chart scored on ONE session's questions, and a participant who then goes on
    # to finish two unrelated sessions. `Create` has no session pre-filter (that lives in
    # `CreateForUserSession#charts`, pinned in its own spec), so all three finishes are evaluated
    # here - which makes this a direct test of the de-dup KEY: on the legacy key this is 3 rows
    # and the chart reports a population of 3 for one person.
    context 'when the chart is scored on one session and the participant finishes two more' do
      let(:formula) do
        {
          'payload' => 'sa.a',
          'patterns' => [{ 'match' => '>=10', 'label' => 'High', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Low', 'color' => '#E2B1F4' }
        }
      end

      let(:session_c) { create(:session, intervention: intervention, variable: 'sc') }
      let(:question_group_c) { create(:question_group, session: session_c) }
      let!(:question_c) do
        create(:question_number, question_group: question_group_c, body: { data: [{ payload: '' }], variable: { name: 'c' } })
      end
      let(:user_session_c) do
        create(:user_session, user: user, session: session_c, user_intervention: user_intervention,
                              health_clinic: health_clinic, finished_at: DateTime.now - 30.minutes)
      end
      let(:answer_c) do
        create(:answer_number, user_session: user_session_c, question: question_c, body: { data: [{ var: 'c', value: '5' }] })
      end

      it 'counts the participant once, not once per finish' do
        expect { described_class.call(chart, user_session_a, organization) }.to change(ChartStatistic, :count).by(1)

        answer_b
        expect { described_class.call(chart, user_session_b, organization) }.not_to change(ChartStatistic, :count)

        answer_c
        expect { described_class.call(chart, user_session_c, organization) }.not_to change(ChartStatistic, :count)

        rows = ChartStatistic.where(chart: chart, user: user)
        expect(rows.count).to eq(1)
        # Neither later session contributes a variable the formula references, so the score - and
        # therefore the label - is unchanged by finishing them. Only `sa.a` is scored.
        expect(rows.first.label).to eq('Low')
      end
    end

    context 'when the participant refills a session in a sibling clinic' do
      # `health_clinic` stays in the de-dup key, so a per-clinic second row is documented
      # dimension behaviour, not duplication - clinic filtering is how the dashboard reads
      # them apart. A same-clinic retake is impossible anyway
      # (`index_user_session_on_u_id_and_s_id_and_hc_id` is unconditionally unique), so a
      # multiple-fill retake always lands in a different clinic. Pinned so the de-dup fix
      # does not over-reach and collapse clinics too.
      let(:sibling_clinic) { create(:health_clinic, health_system: health_system) }
      let(:session_a) { create(:session, intervention: intervention, variable: 'sa', multiple_fill: true) }

      let(:retake_user_session) do
        create(:user_session, user: user, session: session_a, user_intervention: user_intervention, multiple_fill: true,
                              health_clinic: sibling_clinic, finished_at: DateTime.now - 30.minutes,
                              created_at: DateTime.now - 30.minutes)
      end
      let(:retake_answer) do
        create(:answer_number, user_session: retake_user_session, question: question_a,
                               body: { data: [{ var: 'a', value: '30' }] })
      end

      it 'still produces a second row' do
        described_class.call(chart, user_session_a, organization)
        retake_answer

        expect { described_class.call(chart, retake_user_session, organization) }.to change(ChartStatistic, :count).by(1)

        rows = ChartStatistic.where(chart: chart, user: user)
        expect(rows.count).to eq(2)
        expect(rows.map(&:health_clinic)).to contain_exactly(health_clinic, sibling_clinic)
      end
    end
  end

  describe 'formula error handling' do
    let(:user_session_finished_at) { DateTime.now }

    context 'when formula has syntax errors' do
      let(:formula) do
        {
          'payload' => 'session_var.fruit + * 5', # Invalid syntax
          'patterns' => [{ 'match' => '=1', 'label' => 'Apple', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Other', 'color' => '#E2B1F4' }
        }
      end

      it 'does not create chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the error with chart details' do
        allow(Rails.logger).to receive(:error)
        subject
        expect(Rails.logger).to have_received(:error).with(
          /ChartStatistics::Create SKIPPED chart_id=#{chart.id}.*formula evaluation failed/
        )
      end

      it 'returns nil to allow other processing to continue' do
        expect(subject).to be_nil
      end
    end

    context 'when formula has tokenizer errors' do
      let(:formula) do
        {
          'payload' => 'session_var.fruit +++', # Tokenizer error
          'patterns' => [{ 'match' => '=1', 'label' => 'Apple', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Other', 'color' => '#E2B1F4' }
        }
      end

      it 'does not create chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the formula that caused the error' do
        allow(Rails.logger).to receive(:error)
        subject
        expect(Rails.logger).to have_received(:error).with(
          /Formula: session_var\.fruit \+\+\+/
        )
      end
    end

    context 'when formula references undefined function' do
      let(:formula) do
        {
          'payload' => 'INVALID_FUNC(session_var.fruit)', # Undefined function
          'patterns' => [{ 'match' => '=1', 'label' => 'Apple', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Other', 'color' => '#E2B1F4' }
        }
      end

      it 'does not create chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the error message' do
        allow(Rails.logger).to receive(:error)
        subject
        expect(Rails.logger).to have_received(:error).with(
          /formula evaluation failed.*#{chart.name}/
        )
      end
    end
  end
end
