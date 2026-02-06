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
      # Should create 2 chart statistics (good_chart1 and good_chart2)
      # Should skip bad_chart due to formula error
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
end
