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

  describe 'formula validity settings' do
    let(:base_formula) do
      {
        'payload' => 'session1.var1 + session1.var2',
        'patterns' => [{ 'match' => '>=1', 'label' => 'Matched', 'color' => '#C766EA' }],
        'default_pattern' => { 'label' => 'NotMatched', 'color' => '#E2B1F4' }
      }
    end

    def build_chart(formula_overrides)
      build(:chart, dashboard_section: dashboard_section, formula: base_formula.merge(formula_overrides))
    end

    describe 'JSON schema' do
      it 'accepts both new keys' do
        expect(build_chart('min_answered_variables' => 9, 'positive_despite_missing_data' => true)).to be_valid
      end

      it 'accepts a zero minimum and a false rescue' do
        expect(build_chart('min_answered_variables' => 0, 'positive_despite_missing_data' => false)).to be_valid
      end

      it 'rejects a non-integer minimum' do
        expect(build_chart('min_answered_variables' => 1.5)).not_to be_valid
      end

      it 'rejects a number for the rescue key' do
        expect(build_chart('positive_despite_missing_data' => 15)).not_to be_valid
      end

      it 'rejects an explicit null for the rescue key' do
        # The only value that isolates the schema layer: the model validator is nil-tolerant
        # for the absent-key legacy path, so `"type": "boolean"` is what rejects this.
        expect(build_chart('positive_despite_missing_data' => nil)).not_to be_valid
      end

      it 'rejects an undeclared extra key' do
        expect(build_chart('some_unknown_key' => 1)).not_to be_valid
      end

      it 'still accepts a legacy formula carrying neither key' do
        expect(build(:chart, dashboard_section: dashboard_section, formula: base_formula)).to be_valid
      end

      it 'rejects the legacy numeric threshold key' do
        # The numeric rescue was replaced by the boolean before the feature ever deployed, so the
        # key is no longer declared in the schema and `additionalProperties: false` rejects it.
        legacy_chart = build(:chart, dashboard_section: dashboard_section,
                                     formula: base_formula.merge('positive_despite_missing_threshold' => 15))

        expect(legacy_chart).not_to be_valid
      end

      it 'lets a pre-existing chart re-save without gaining the new keys' do
        legacy_chart = create(:chart, dashboard_section: dashboard_section, formula: base_formula)

        legacy_chart.update!(description: 'Touched')

        expect(legacy_chart.reload.formula).to eq(base_formula)
      end
    end

    describe 'model validation' do
      it 'rejects a negative minimum' do
        chart = build_chart('min_answered_variables' => -1)

        expect(chart).not_to be_valid
      end

      it 'rejects a non-boolean rescue value' do
        chart = build_chart('positive_despite_missing_data' => 'yes')

        expect(chart).not_to be_valid
        expect(chart.errors[:formula]).to include('positive_despite_missing_data must be a boolean')
      end

      it 'accepts a chart with neither key' do
        expect(build(:chart, dashboard_section: dashboard_section, formula: base_formula)).to be_valid
      end

      it 'does not enforce a min <= formula_variable_count ceiling' do
        # Deliberate: the FE autosaves the payload on blur carrying the previous min,
        # so a ceiling would 422 routine payload edits into a silent revert.
        chart = build_chart('payload' => 'session1.var1', 'min_answered_variables' => 9)

        expect(chart).to be_valid
      end
    end

    describe 'reserved label collision guard' do
      let(:reserved) { ChartStatistic::INSUFFICIENT_DATA_LABEL }
      let(:error_message) do
        "label '#{reserved}' is reserved for participants excluded by the validity gate " \
          'and cannot be used by a case or by the default category'
      end

      it 'rejects a case whose label is the reserved label' do
        chart = build_chart('patterns' => [{ 'match' => '>=1', 'label' => reserved, 'color' => '#C766EA' }])

        expect(chart).not_to be_valid
        expect(chart.errors[:formula]).to include(error_message)
      end

      it 'rejects the reserved label regardless of case' do
        chart = build_chart('patterns' => [{ 'match' => '>=1', 'label' => 'invalid / INSUFFICIENT data', 'color' => '#C766EA' }])

        expect(chart).not_to be_valid
      end

      it 'rejects the reserved label on the default category' do
        chart = build_chart('default_pattern' => { 'label' => reserved, 'color' => '#E2B1F4' })

        expect(chart).not_to be_valid
        expect(chart.errors[:formula]).to include(error_message)
      end

      it 'rejects the reserved label on a case beyond the first' do
        # `formula.json`'s `items` is a draft-04 TUPLE, so `patterns[1..]` reaches no schema
        # constraint at all - this guard is the only thing checking those elements.
        chart = build_chart('patterns' => [
                              { 'match' => '>=10', 'label' => 'Severe', 'color' => '#C766EA' },
                              { 'match' => '>=1', 'label' => reserved, 'color' => '#E2B1F4' }
                            ])

        expect(chart).not_to be_valid
      end

      it 'accepts a merely similar label' do
        chart = build_chart('patterns' => [{ 'match' => '>=1', 'label' => 'Insufficient data', 'color' => '#C766EA' }])

        expect(chart).to be_valid
      end

      it 'tolerates malformed patterns and a malformed default_pattern without raising' do
        # `formula.json` constrains no pattern item and leaves `default_pattern`
        # unconstrained, so the guard must survive whatever survives the schema.
        %w[patterns default_pattern].each do |key|
          chart = build(:chart, dashboard_section: dashboard_section,
                                formula: base_formula.merge(key => 'not a collection'))

          expect { chart.valid? }.not_to raise_error
        end
      end

      it 'tolerates a non-Hash case element and a non-String label' do
        chart = build_chart('patterns' => ['just a string', { 'match' => '>=1', 'label' => 5 }, { 'match' => '>=0' }])

        expect { chart.valid? }.not_to raise_error
        expect(chart.errors[:formula]).not_to include(error_message)
      end

      it 'tolerates the case elements that would actually raise without the type guards' do
        # Deliberately the two fixtures that make the guards falsifiable: `'a string'['label']`
        # merely returns nil, so the examples above stay green even with the guards deleted.
        # Delete `pattern.is_a?(Hash)` and `nil['label']` raises NoMethodError; delete
        # `default_pattern.is_a?(Hash)` and `5['label']` raises TypeError.
        expect { build_chart('patterns' => [{ 'match' => '>=1', 'label' => 'Ok' }, nil, 5]).valid? }.not_to raise_error
        expect { build_chart('default_pattern' => 5).valid? }.not_to raise_error
      end
    end

    describe '#formula_variable_count' do
      def count_for(payload)
        build(:chart, dashboard_section: dashboard_section,
                      formula: base_formula.merge('payload' => payload)).formula_variable_count
      end

      it 'ignores decimal coefficients' do
        expect(count_for('HT2.phq1 * 1.5 + HT2.phq2')).to eq(2)
      end

      it 'counts repeated variables once' do
        expect(count_for('A.b+A.c+A.b')).to eq(2)
      end

      it 'handles dot-containing variable names' do
        expect(count_for('HT2.phq.1 + HT2.phq.2')).to eq(2)
      end

      it 'returns 0 for an empty payload' do
        expect(count_for('')).to eq(0)
      end

      it 'returns nil for a malformed payload and still saves the chart' do
        chart = build(:chart, dashboard_section: dashboard_section,
                              formula: base_formula.merge('payload' => 'HT2.phq1 +'))

        expect(chart.formula_variable_count).to be_nil
        expect { chart.save! }.not_to raise_error
      end

      it 'is invariant to participant answer state' do
        # Guards the fresh-calculator constraint: Dentaku#dependencies only returns
        # identifiers absent from calculator memory, so a loaded calculator under-counts.
        chart = create(:chart, dashboard_section: dashboard_section,
                               formula: base_formula.merge('payload' => 'session1.var1 + session1.var2'))
        before_answers = chart.formula_variable_count

        question = create(:question_number, question_group: question_group1, body: {
                            data: [{ payload: '' }], variable: { name: 'var1' }
                          })
        user_session = create(:user_session, session: session1, user: create(:user, :confirmed, :participant))
        create(:answer_number, question: question, user_session: user_session,
                               body: { data: [{ var: 'var1', value: '3' }] })

        expect(chart.reload.formula_variable_count).to eq(before_answers).and eq(2)
      end
    end
  end

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

    it 'caches per-intervention so successive calls with different interventions return their own questions' do
      # Regression: previously the result was memoized in a single ivar without
      # keying on intervention, so a Chart instance reused across multiple
      # interventions (CreateForUserSessions bulk path) would lock in the first
      # intervention's vars and misclassify formulas for the rest.
      other_intervention = create(:intervention, :published, organization: organization)
      other_session = create(:session, intervention: other_intervention, variable: 'session1')
      other_question_group = create(:question_group, session: other_session)
      create(:question_single, question_group: other_question_group, body: {
               data: [{ payload: 'option1', value: '1' }],
               variable: { name: 'other_intervention_var' }
             })

      first_result = chart.send(:intervention_question_variables, intervention)
      second_result = chart.send(:intervention_question_variables, other_intervention)

      expect(first_result).to match_array(%w[var1 var2])
      expect(second_result).to contain_exactly('other_intervention_var')
      expect(second_result).not_to include('var1', 'var2')
    end
  end
end
