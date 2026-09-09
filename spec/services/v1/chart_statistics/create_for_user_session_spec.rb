# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::CreateForUserSession do
  subject { described_class.call(@user_session) }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let_it_be(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let_it_be(:health_system) { create(:health_system, organization: organization) }
  let_it_be(:health_clinic) { create(:health_clinic, health_system: health_system) }
  let_it_be(:intervention) { create(:intervention, :published, organization: organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:session_var) { 'session_var' }
  let_it_be(:filled_at) { DateTime.current }

  context 'when chart is published' do
    let_it_be(:formula1) do
      { 'payload' => "#{session_var}.color + #{session_var}.sport",
        'patterns' => [
          {
            'match' => '=2',
            'label' => 'Label1',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'Other',
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:formula2) do
      { 'payload' => "#{session_var}.color + #{session_var}.sport",
        'patterns' => [
          {
            'match' => '=5',
            'label' => 'Label1',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'Other',
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:formula3) do
      { 'payload' => "#{session_var}.color + #{session_var}.sport",
        'patterns' => [
          {
            'match' => '=2',
            'label' => 'Matched',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'NotMatched',
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:formula4) do
      { 'payload' => "#{session_var}.color + #{session_var}.sport",
        'patterns' => [
          {
            'match' => '=4',
            'label' => 'Matched',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'NotMatched',
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:pie_chart1) do
      create(:chart, formula: formula1, dashboard_section: dashboard_section, status: 'published', published_at: Time.current,
                     chart_type: Chart.chart_types[:pie_chart])
    end
    let_it_be(:pie_chart2) do
      create(:chart, formula: formula2, dashboard_section: dashboard_section, status: 'published', published_at: Time.current,
                     chart_type: Chart.chart_types[:pie_chart])
    end
    let_it_be(:bar_chart1) do
      create(:chart, formula: formula3, dashboard_section: dashboard_section, status: 'published', published_at: Time.current,
                     chart_type: Chart.chart_types[:bar_chart])
    end
    let_it_be(:bar_chart2) do
      create(:chart, formula: formula4, dashboard_section: dashboard_section, status: 'published', published_at: Time.current,
                     chart_type: Chart.chart_types[:bar_chart])
    end

    context 'when user session contains all values of chart formula' do
      before_all do
        RSpec::Mocks.with_temporary_scope do
          allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
          session = create(:session, intervention: intervention, variable: session_var)
          @user_session = create(:user_session, session: session, user: user, health_clinic: health_clinic)
          @answer1 = create(:answer_single, user_session: @user_session, body: { data: [{ var: 'color', value: '1' }] })
          @answer2 = create(:answer_single, user_session: @user_session, body: { data: [{ var: 'sport', value: '1' }] })
        end
      end
      let(:answer1) { @answer1 }
      let(:answer2) { @answer2 }

      it 'create chart statistics for bar charts and pie charts' do
        expect { subject }.to change(ChartStatistic, :count).by(4)
        chart_statistics = ChartStatistic.where(
          organization: organization,
          health_system: health_system,
          health_clinic: health_clinic,
          user: user
        )

        expect(chart_statistics.exists?(label: 'Label1', chart: pie_chart1)).to be true
        expect(chart_statistics.exists?(label: 'Other', chart: pie_chart2)).to be true
        expect(chart_statistics.exists?(label: 'Matched', chart: bar_chart1)).to be true
        expect(chart_statistics.exists?(label: 'NotMatched', chart: bar_chart2)).to be true
      end
    end

    # NOTE: this context does NOT exercise the never-reached / answered-none guard, despite its
    # title. The `answer_single` factory builds its question in its OWN intervention
    # (spec/factories/answers.rb), so `sport` exists in no question of THIS intervention and
    # `Create` exits at the invalid-variables branch (create.rb:21-28) long before any
    # answeredness is measured. It stays as-is because that branch is worth covering; the
    # genuine cross-session case is the describe block at the bottom of this file.
    context "when user session doesn't contain all values of chart formula" do
      before_all do
        RSpec::Mocks.with_temporary_scope do
          allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
          session = create(:session, intervention: intervention, variable: session_var)
          @user_session = create(:user_session, session: session, user: user, health_clinic: health_clinic)
          @answer1 = create(:answer_single, user_session: @user_session, body: { data: [{ var: 'color', value: '1' }] })
        end
      end
      let(:answer1) { @answer1 }

      it "Don't create chart statistic" do
        expect { subject }.not_to change(ChartStatistic, :count)
      end
    end
  end

  context 'when formula divides by zero' do
    let_it_be(:formula5) do
      { 'payload' => "#{session_var}.color / #{session_var}.sport",
        'patterns' => [
          {
            'match' => '=5',
            'label' => 'Matched',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'NotMatched',
          'color' => '#E2B1F4'
        } }
    end

    let_it_be(:bar_chart3) do
      create(:chart, formula: formula5, dashboard_section: dashboard_section, status: 'published', published_at: Time.current,
                     chart_type: Chart.chart_types[:bar_chart])
    end
    before_all do
      RSpec::Mocks.with_temporary_scope do
        allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
        session = create(:session, intervention: intervention, variable: session_var)
        @user_session = create(:user_session, session: session, user: user, health_clinic: health_clinic, finished_at: filled_at)
        @answer1 = create(:answer_single, user_session: @user_session, body: { data: [{ var: 'color', value: '1' }] })
        @answer2 = create(:answer_single, user_session: @user_session, body: { data: [{ var: 'sport', value: '0' }] })
      end
    end

    it "Don't create chart statistic" do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  context "when chart doesn't published" do
    before_all do
      RSpec::Mocks.with_temporary_scope do
        allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
        session = create(:session, intervention: intervention, variable: session_var)
        @user_session = create(:user_session, session: session, user: user, health_clinic: health_clinic)
      end
    end
    let(:chart) { create(:chart, dashboard_section: dashboard_section, published_at: nil) }

    it "Don't create chart statistic" do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  context 'when one chart has formula errors but others are valid' do
    let_it_be(:good_formula) do
      { 'payload' => "#{session_var}.color",
        'patterns' => [
          {
            'match' => '=1',
            'label' => 'Valid',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'Other',
          'color' => '#E2B1F4'
        } }
    end

    let_it_be(:bad_formula) do
      { 'payload' => 'session_var.color + * invalid', # Invalid syntax
        'patterns' => [
          {
            'match' => '=1',
            'label' => 'Bad',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'Other',
          'color' => '#E2B1F4'
        } }
    end

    before_all do
      RSpec::Mocks.with_temporary_scope do
        allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
        session = create(:session, intervention: intervention, variable: session_var)
        question_group = create(:question_group, session: session)
        create(:question_single, question_group: question_group,
                                 body: { data: [{ payload: 'Red', value: '1' }], variable: { name: 'color' } })
        @user_session = create(:user_session, session: session, user: user, health_clinic: health_clinic)
        create(:answer_single, user_session: @user_session, body: { data: [{ var: 'color', value: '1' }] })
      end
    end

    let_it_be(:good_chart1) do
      create(:chart, formula: good_formula, dashboard_section: dashboard_section, status: 'published',
                     published_at: Time.current, chart_type: Chart.chart_types[:pie_chart])
    end

    let_it_be(:bad_chart) do
      create(:chart, formula: bad_formula, dashboard_section: dashboard_section, status: 'published',
                     published_at: Time.current, chart_type: Chart.chart_types[:pie_chart], name: 'Bad Chart')
    end

    let_it_be(:good_chart2) do
      create(:chart, formula: good_formula, dashboard_section: dashboard_section, status: 'published',
                     published_at: Time.current, chart_type: Chart.chart_types[:bar_chart])
    end

    it 'creates chart statistics for valid charts and skips the invalid one' do
      expect { subject }.to change(ChartStatistic, :count).by(2)
    end

    it 'logs error for the invalid chart' do
      allow(Rails.logger).to receive(:error)
      subject
      expect(Rails.logger).to have_received(:error).with(
        /ChartStatistics::Create SKIPPED chart_id=#{bad_chart.id}.*formula evaluation failed.*Bad Chart/
      )
    end

    it 'does not raise an exception' do
      expect { subject }.not_to raise_error
    end
  end

  # WI-17. `charts` used to select EVERY non-draft chart in the organization with no session
  # filter, so an `ht1`-scoped chart was re-evaluated at an unrelated `ht2` finish. It now
  # mirrors the replay path (`CreateForUserSessions#chart_session_variables`,
  # create_for_user_sessions.rb:42-44), which removes the live-vs-replay divergence as well.
  describe 'session pre-filter' do
    let(:user_intervention) do
      create(:user_intervention, user: filtering_user, intervention: intervention, health_clinic_id: health_clinic.id)
    end
    let(:filtering_user) { create(:user, :participant, :confirmed) }

    let(:screening_session) { create(:session, intervention: intervention, variable: 'ht1') }
    let(:followup_session) { create(:session, intervention: intervention, variable: 'ht2') }
    let(:screening_group) { create(:question_group, session: screening_session) }
    let(:followup_group) { create(:question_group, session: followup_session) }

    let!(:screening_questions) do
      %w[a b].map do |name|
        create(:question_number, question_group: screening_group,
                                 body: { data: [{ payload: '' }], variable: { name: name } })
      end
    end
    let!(:followup_question) do
      create(:question_number, question_group: followup_group,
                               body: { data: [{ payload: '' }], variable: { name: 'c' } })
    end

    let(:screening_finish) do
      create(:user_session, user: filtering_user, session: screening_session, user_intervention: user_intervention,
                            health_clinic: health_clinic, finished_at: DateTime.now - 2.hours)
    end
    let(:followup_finish) do
      create(:user_session, user: filtering_user, session: followup_session, user_intervention: user_intervention,
                            health_clinic: health_clinic, finished_at: DateTime.now)
    end

    def chart_with(payload, min_answered_variables: nil)
      formula = {
        'payload' => payload,
        'patterns' => [{ 'match' => '>=1', 'label' => 'Matched', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'Not matched', 'color' => '#E2B1F4' }
      }
      formula['min_answered_variables'] = min_answered_variables unless min_answered_variables.nil?

      create(:chart, dashboard_section: dashboard_section, status: 'published', published_at: Time.current,
                     chart_type: Chart.chart_types[:pie_chart], formula: formula)
    end

    context 'when the chart formula references only the screening session' do
      let!(:screening_chart) { chart_with('ht1.a + ht1.b') }

      let!(:screening_answers) do
        screening_questions.each_with_index.map do |question, index|
          create(:answer_number, user_session: screening_finish, question: question,
                                 body: { data: [{ var: %w[a b][index], value: '5' }] })
        end
      end
      let!(:followup_answer) do
        create(:answer_number, user_session: followup_finish, question: followup_question,
                               body: { data: [{ var: 'c', value: '1' }] })
      end

      it 'is not evaluated at an unrelated follow-up finish, and the existing row keeps its date' do
        expect { described_class.call(screening_finish) }.to change(ChartStatistic, :count).by(1)
        row = ChartStatistic.find_by(chart: screening_chart, user: filtering_user)
        expect(row.filled_at).to be_within(1.second).of(screening_finish.finished_at)

        # Without the pre-filter this finish finds the same de-duplicated row and drags
        # `filled_at` forward to the follow-up date, relocating the participant from the month
        # they were screened in to the month they finished something else - which moves their
        # bar on a monthly bar chart.
        expect { described_class.call(followup_finish) }.not_to change(ChartStatistic, :count)
        expect(row.reload.filled_at).to be_within(1.second).of(screening_finish.finished_at)
        expect(row.user_session).to eq(screening_finish)
      end
    end

    context 'when the chart formula spans both sessions' do
      let!(:spanning_chart) { chart_with('ht1.a + ht2.c') }

      let!(:screening_answer) do
        create(:answer_number, user_session: screening_finish, question: screening_questions.first,
                               body: { data: [{ var: 'a', value: '1' }] })
      end
      # Lazy: the follow-up must not be filled in before the screening session finishes.
      let(:followup_answer) do
        create(:answer_number, user_session: followup_finish, question: followup_question,
                               body: { data: [{ var: 'c', value: '1' }] })
      end

      it 'is evaluated at both finishes and keeps one row' do
        expect { described_class.call(screening_finish) }.to change(ChartStatistic, :count).by(1)
        row = ChartStatistic.find_by(chart: spanning_chart, user: filtering_user)
        expect(row.filled_at).to be_within(1.second).of(screening_finish.finished_at)

        followup_answer
        expect { described_class.call(followup_finish) }.not_to change(ChartStatistic, :count)
        expect(row.reload.filled_at).to be_within(1.second).of(followup_finish.finished_at)
        expect(row.user_session).to eq(followup_finish)
      end
    end

    # The guard's SECOND job at this level. The chart spans both sessions, so the pre-filter
    # admits it at the follow-up finish - and the participant, who never opened the screening
    # session and was branched around the follow-up question, must still not get an all-zeros
    # row. This is what makes the org-wide chart selection safe.
    context 'when the participant answered none of a spanning chart\'s questions' do
      let!(:spanning_chart) { chart_with('ht1.a + ht2.c') }

      let!(:unrelated_question) do
        create(:question_number, question_group: followup_group,
                                 body: { data: [{ payload: '' }], variable: { name: 'unrelated' } })
      end
      let!(:unrelated_answer) do
        create(:answer_number, user_session: followup_finish, question: unrelated_question,
                               body: { data: [{ var: 'unrelated', value: '7' }] })
      end

      it 'does not create a chart statistic' do
        expect { described_class.call(followup_finish) }.not_to change(ChartStatistic, :count)
      end

      it 'logs the answered-none skip' do
        allow(Rails.logger).to receive(:info)
        described_class.call(followup_finish)
        expect(Rails.logger).to have_received(:info).with(
          /SKIPPED chart_id=#{spanning_chart.id}.*answered NONE of the questions referenced by formula/
        )
      end
    end

    # The pre-filter is gate-INDEPENDENT by design: `charts` runs before any chart is
    # evaluated and before `validity_gate_enabled?` is ever consulted, so a GATED chart also
    # stops being evaluated - and stops dragging `filled_at` - at a finish its formula does
    # not reference. That IS a gated-path behaviour change, accepted because a gate-conditional
    # pre-filter would reinstate the live-vs-replay chart-selection divergence the pre-filter
    # exists to remove, for gated charts only. Zero
    # production impact: `min_answered_variables` does not exist on `origin/dev`, so there
    # are no gated charts anywhere.
    context 'when a GATED chart references only the screening session' do
      let!(:gated_screening_chart) { chart_with('ht1.a + ht1.b', min_answered_variables: 1) }

      let!(:screening_answers) do
        screening_questions.each_with_index.map do |question, index|
          create(:answer_number, user_session: screening_finish, question: question,
                                 body: { data: [{ var: %w[a b][index], value: '5' }] })
        end
      end
      let!(:followup_answer) do
        create(:answer_number, user_session: followup_finish, question: followup_question,
                               body: { data: [{ var: 'c', value: '1' }] })
      end

      it 'is skipped at the unrelated follow-up finish too, and the row keeps its date' do
        expect { described_class.call(screening_finish) }.to change(ChartStatistic, :count).by(1)
        row = ChartStatistic.find_by(chart: gated_screening_chart, user: filtering_user)
        expect(row.label).to eq('Matched')
        expect(row.filled_at).to be_within(1.second).of(screening_finish.finished_at)

        # Make the pre-filter gate-conditional and this is what breaks: the gated chart is
        # re-evaluated at the follow-up finish, passes its own gate (both variables are in
        # `all_var_values`, which spans the whole user_intervention), finds the single
        # de-duplicated row and drags `filled_at` forward.
        expect { described_class.call(followup_finish) }.not_to change(ChartStatistic, :count)
        expect(row.reload.filled_at).to be_within(1.second).of(screening_finish.finished_at)
        expect(row.user_session).to eq(screening_finish)
      end
    end

    # A payload carrying no `session_variable.question_variable` token matches no session, so
    # such a chart is skipped at EVERY finish - which is what the replay path has always done
    # with it (`sessions.variable IN ()` matches nothing). Pinned because the rows it used to
    # produce on the live path were all-zeros and uninformative (`all_var_values` keys are
    # always session-qualified - `UserInterventionService` passes `current_user_session_id`
    # nil, so `user_session.rb:26` always emits `"#{session.variable}.#{var}"`, and a bare
    # identifier can never be in calculator memory), and a future dev "fixing" the pre-filter
    # back would silently reintroduce them. Query 2c of the WI-3 script is the pre-deploy
    # canary for charts of this shape that already hold rows.
    context 'when the chart formula uses BARE unqualified variable names' do
      let!(:bare_chart) { chart_with('a + b') }

      let!(:screening_answers) do
        screening_questions.each_with_index.map do |question, index|
          create(:answer_number, user_session: screening_finish, question: question,
                                 body: { data: [{ var: %w[a b][index], value: '5' }] })
        end
      end

      it 'is not evaluated at any finish' do
        expect { described_class.call(screening_finish) }.not_to change(ChartStatistic, :count)
        expect { described_class.call(followup_finish) }.not_to change(ChartStatistic, :count)
        expect(ChartStatistic.where(chart: bare_chart)).to be_empty
      end
    end
  end
end
