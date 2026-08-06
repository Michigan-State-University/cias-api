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

    context 'when user did not reach all questions referenced by formula (branched-around)' do
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

      it 'logs the skip with the branched-around message' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(/did not reach all questions referenced by formula/)
      end
    end

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

      it 'does not create chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end
    end
  end

  describe 'chart validity gate (min_answered_variables > 0)' do
    let(:user_session_finished_at) { DateTime.now }
    let(:question_group) { create(:question_group, session: session) }
    let(:min_answered_variables) { 7 }
    let(:threshold) { nil }
    let(:answered_variables) { 3 }
    let(:answer_value) { '1' }

    let(:formula) do
      {
        'payload' => (1..9).map { |i| "session_var.epds#{i}" }.join(' + '),
        'patterns' => [{ 'match' => '>=2', 'label' => 'Positive', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
        'min_answered_variables' => min_answered_variables,
        'positive_despite_missing_threshold' => threshold
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
      it 'does not create a chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end

      it 'logs the exclusion with the counts, score and threshold' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).to have_received(:info).with(
          /EXCLUDED chart_id=#{chart.id}.*answered=3 required=7 of=9 score=3 threshold=nil/
        )
      end
    end

    context 'when exactly the minimum is answered' do
      let(:answered_variables) { 7 }

      it 'creates a chart statistic labelled by the 0-filled score' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq('Positive')
      end

      it 'bypasses the never-reached-question guard' do
        allow(Rails.logger).to receive(:info)
        subject
        expect(Rails.logger).not_to have_received(:info).with(/did not reach all questions referenced by formula/)
      end
    end

    context 'when a skipped answer leaves its variable blank' do
      let(:answered_variables) { 6 }

      let!(:skipped_answer) do
        create(:answer_single, user_session: user_session, question: epds_questions[6], skipped: true,
                               body: { data: [{ var: '', value: '' }] })
      end

      it 'does not count the skipped question towards the minimum' do
        expect { subject }.not_to change(ChartStatistic, :count)
      end
    end

    context 'when the participant is below the minimum but the score clears the threshold' do
      let(:threshold) { 15 }
      let(:answer_value) { '10' }

      it 'rescues the participant and labels them by the ordinary patterns' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
        expect(ChartStatistic.last.label).to eq('Positive')
      end
    end

    context 'when the score exactly equals the threshold' do
      let(:threshold) { 15 }
      let(:answer_value) { '5' }

      it 'rescues the participant' do
        expect { subject }.to change(ChartStatistic, :count).by(1)
      end
    end

    context 'when the participant is below the minimum and the score misses the threshold' do
      let(:threshold) { 15 }

      it 'does not create a chart statistic' do
        expect { subject }.not_to change(ChartStatistic, :count)
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
          'positive_despite_missing_threshold' => threshold
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
        # participant's other finished session. Exclusion skips the upsert - it never destroys.
        chart.update!(formula: chart.formula.merge('min_answered_variables' => 5))
        answer_b

        expect { described_class.call(chart, user_session_b, organization) }.not_to change(ChartStatistic, :count)
        expect(statistic.reload.label).to eq('Low')
        expect(statistic.user_session).to eq(user_session_a)
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
          'min_answered_variables' => min_answered_variables,
          'positive_despite_missing_threshold' => nil
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
        expect { described_class.call(chart, retake_fill, organization) }.not_to change(ChartStatistic, :count)

        statistic.reload
        expect(statistic.label).to eq('Positive')
        expect(statistic.user_session).to eq(first_fill)
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
