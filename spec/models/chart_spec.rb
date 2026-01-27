# frozen_string_literal: true

RSpec.describe Chart do
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }

  let(:intervention) { create(:intervention, :published, organization: organization) }
  let(:session1) { create(:session, intervention: intervention, variable: 'session1') }
  let(:session2) { create(:session, intervention: intervention, variable: 'session2') }
  let(:question_group1) { create(:question_group, session: session1) }
  let(:question_group2) { create(:question_group, session: session2) }

  let(:chart) { create(:chart, dashboard_section: dashboard_section) }

  describe '#validate_formula_variables' do
    context 'when missing_vars is blank' do
      it 'returns empty array for nil' do
        result = chart.validate_formula_variables(nil, intervention)
        expect(result).to eq([])
      end

      it 'returns empty array for empty array' do
        result = chart.validate_formula_variables([], intervention)
        expect(result).to eq([])
      end
    end

    context 'when all missing variables exist in intervention questions' do
      let!(:question1) do
        create(:question_single, question_group: question_group1, body: {
                 data: [{ payload: 'option1', value: '1' }, { payload: 'option2', value: '2' }],
                 variable: { name: 'fruit' }
               })
      end

      let!(:question2) do
        create(:question_number, question_group: question_group2, body: {
                 data: [{ payload: '' }],
                 variable: { name: 'age' }
               })
      end

      it 'returns empty array when all variables are valid' do
        missing_vars = ['session1.fruit', 'session2.age']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to eq([])
      end

      it 'handles variables without session prefix' do
        missing_vars = %w[fruit age]
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to eq([])
      end
    end

    context 'when some missing variables do not exist in intervention questions' do
      let!(:question1) do
        create(:question_single, question_group: question_group1, body: {
                 data: [{ payload: 'option1', value: '1' }],
                 variable: { name: 'fruit' }
               })
      end

      it 'returns only the invalid variables' do
        missing_vars = ['session1.fruit', 'session1.invalid_var', 'session2.another_invalid']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to contain_exactly('session1.invalid_var', 'session2.another_invalid')
      end

      it 'returns invalid variables even without session prefix' do
        missing_vars = %w[fruit invalid_var another_invalid]
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to match_array(%w[invalid_var another_invalid])
      end
    end

    context 'when all missing variables are invalid' do
      it 'returns all variables' do
        missing_vars = ['session1.invalid1', 'session2.invalid2', 'invalid3']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to match_array(missing_vars)
      end
    end

    context 'with multiple question types' do
      let!(:single_question) do
        create(:question_single, question_group: question_group1, body: {
                 data: [{ payload: 'yes', value: '1' }, { payload: 'no', value: '0' }],
                 variable: { name: 'single_var' }
               })
      end

      let!(:multiple_question) do
        create(:question_multiple, question_group: question_group2, body: {
                 data: [
                   { payload: 'option1', variable: { name: 'answer_1', value: '' } },
                   { payload: 'option2', variable: { name: 'answer_2', value: '' } }
                 ]
               })
      end

      let!(:slider_question) do
        create(:question_slider, question_group: question_group1, body: {
                 data: [{ payload: { range_start: 0, range_end: 100, start_value: 'Low', end_value: 'High' } }],
                 variable: { name: 'slider_var' }
               })
      end

      it 'validates variables from different question types' do
        missing_vars = ['session1.single_var', 'session2.answer_1', 'session2.answer_2', 'session1.slider_var']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to eq([])
      end

      it 'identifies invalid variables among valid ones' do
        missing_vars = ['session1.single_var', 'session2.answer_1', 'session1.invalid', 'session2.answer_2']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to eq(['session1.invalid'])
      end
    end

    context 'with grid questions' do
      let!(:grid_question) do
        create(:question_grid, question_group: question_group1, body: {
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

      it 'validates grid row variables' do
        missing_vars = ['session1.row1', 'session1.row2']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to eq([])
      end

      it 'identifies invalid grid variables' do
        missing_vars = ['session1.row1', 'session1.invalid_row']
        result = chart.validate_formula_variables(missing_vars, intervention)
        expect(result).to eq(['session1.invalid_row'])
      end
    end
  end

  describe '#intervention_question_variables' do
    let!(:question1) do
      create(:question_single, question_group: question_group1, body: {
               data: [{ payload: 'option1', value: '1' }],
               variable: { name: 'var1' }
             })
    end

    let!(:question2) do
      create(:question_number, question_group: question_group2, body: {
               data: [{ payload: '' }],
               variable: { name: 'var2' }
             })
    end

    it 'caches the result' do
      # First call
      result1 = chart.send(:intervention_question_variables, intervention)

      # Create a new question after first call
      create(:question_slider, question_group: question_group1, body: {
               data: [{ payload: { range_start: 0, range_end: 100, start_value: 'Low', end_value: 'High' } }],
               variable: { name: 'var3' }
             })

      # Second call should return cached result (without var3)
      result2 = chart.send(:intervention_question_variables, intervention)

      expect(result1).to eq(result2)
      expect(result1).to match_array(%w[var1 var2])
    end

    it 'returns all unique question variables from the intervention' do
      result = chart.send(:intervention_question_variables, intervention)
      expect(result).to match_array(%w[var1 var2])
    end

    it 'filters questions only from the specified intervention' do
      other_intervention = create(:intervention, :published, organization: organization)
      other_session = create(:session, intervention: other_intervention, variable: 'other_session')
      other_question_group = create(:question_group, session: other_session)
      create(:question_single, question_group: other_question_group, body: {
               data: [{ payload: 'option1', value: '1' }],
               variable: { name: 'other_var' }
             })

      result = chart.send(:intervention_question_variables, intervention)
      expect(result).to match_array(%w[var1 var2])
      expect(result).not_to include('other_var')
    end
  end
end
