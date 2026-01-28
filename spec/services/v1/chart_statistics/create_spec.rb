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
      let!(:answer_multi) { create(:answer_multiple, user_session: user_session, body: { data: [{ var: 'option_1', value: '1' }] }) }

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
  end
end
