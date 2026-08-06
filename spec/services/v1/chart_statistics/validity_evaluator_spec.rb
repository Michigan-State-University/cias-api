# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::ValidityEvaluator do
  subject(:result) { described_class.call(chart, var_values, score) }

  let(:payload) { 'HT2.q1 + HT2.q2 + HT2.q3 + HT2.q4' }
  let(:min_answered_variables) { 3 }
  let(:threshold) { nil }
  let(:score) { nil }
  let(:var_values) { {} }
  let(:formula) do
    {
      'payload' => payload,
      'patterns' => [{ 'match' => '>=10', 'label' => 'Positive', 'color' => '#C766EA' }],
      'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
      'min_answered_variables' => min_answered_variables,
      'positive_despite_missing_threshold' => threshold
    }
  end
  let(:chart) { build(:chart, formula: formula) }

  describe 'class-level readers' do
    it 'reports the gate as enabled and exposes both settings' do
      expect(described_class.enabled?(chart)).to be true
      expect(described_class.min_answered_variables(chart)).to eq(3)
      expect(described_class.threshold(chart)).to be_nil
    end

    context 'with a legacy formula that carries neither key' do
      let(:formula) do
        {
          'payload' => payload,
          'patterns' => [{ 'match' => '>=10', 'label' => 'Positive', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' }
        }
      end

      it 'reports the gate as disabled without raising' do
        expect(described_class.enabled?(chart)).to be false
        expect(described_class.min_answered_variables(chart)).to eq(0)
        expect(described_class.threshold(chart)).to be_nil
      end
    end
  end

  describe 'the answered count' do
    it 'reports the number of formula variables (M)' do
      expect(result.variable_count).to eq(4)
    end

    context 'when every referenced variable has a value' do
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1', 'HT2.q3' => '1', 'HT2.q4' => '1' } }

      it 'counts them all and passes' do
        expect(result.answered_count).to eq(4)
        expect(result.passed).to be true
        expect(result.rescued).to be false
      end
    end

    context 'when a variable was answered with 0' do
      let(:var_values) { { 'HT2.q1' => '0', 'HT2.q2' => 0, 'HT2.q3' => '0' } }

      it 'counts a zero answer as answered' do
        expect(result.answered_count).to eq(3)
        expect(result.passed).to be true
      end
    end

    context 'when a variable was genuinely answered 888' do
      # 888 is only the CSV export's skip sentinel (Intervention::Csv::Harvester::DEFAULT_VALUE);
      # a participant who really answered 888 has answered the question.
      let(:var_values) { { 'HT2.q1' => '888', 'HT2.q2' => 888, 'HT2.q3' => '1' } }

      it 'counts 888 as answered' do
        expect(result.answered_count).to eq(3)
        expect(result.passed).to be true
      end
    end

    context 'when questions were skipped, branched around, timed out or left in draft' do
      # All four leave no key in var_values at all: skipped answers submit a blank
      # `var` (filtered by UserSession#all_var_values), the rest leave no confirmed row.
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1' } }

      it 'does not count the absent variables' do
        expect(result.answered_count).to eq(2)
        expect(result.passed).to be false
      end
    end

    context 'when var values carry variables the formula does not reference' do
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.other' => '1', 'OTHER.q2' => '1' } }

      it 'counts only the formula variables' do
        expect(result.answered_count).to eq(1)
      end
    end

    context 'when the payload cannot be parsed' do
      let(:payload) { 'HT2.q1 +' }

      it 'reports no variables and excludes' do
        expect(result.variable_count).to be_nil
        expect(result.answered_count).to eq(0)
        expect(result.passed).to be false
      end
    end
  end

  describe 'the count gate' do
    context 'when exactly the minimum is answered' do
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1', 'HT2.q3' => '1' } }

      it 'passes on the boundary' do
        expect(result.passed).to be true
        expect(result.rescued).to be false
      end
    end

    context 'when one below the minimum is answered' do
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1' } }

      it 'does not pass' do
        expect(result.passed).to be false
      end
    end

    context 'when the minimum is 0' do
      let(:min_answered_variables) { 0 }

      it 'is off — everyone passes with nothing answered' do
        expect(result.answered_count).to eq(0)
        expect(result.passed).to be true
        expect(result.rescued).to be false
      end
    end

    context 'when the minimum key is absent' do
      let(:formula) do
        {
          'payload' => payload,
          'patterns' => [{ 'match' => '>=10', 'label' => 'Positive', 'color' => '#C766EA' }],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' }
        }
      end

      it 'is off' do
        expect(result.passed).to be true
      end
    end

    context 'when the minimum exceeds the number of formula variables' do
      let(:min_answered_variables) { 5 }
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1', 'HT2.q3' => '1', 'HT2.q4' => '1' } }

      it 'nobody passes on count' do
        expect(result.answered_count).to eq(4)
        expect(result.passed).to be false
      end

      context 'and a numeric score clears the threshold' do
        let(:threshold) { 15 }
        let(:score) { 20 }

        it 'is still rescued' do
          expect(result.passed).to be true
          expect(result.rescued).to be true
        end
      end
    end
  end

  describe 'the threshold rescue' do
    let(:var_values) { { 'HT2.q1' => '1' } }
    let(:threshold) { 15 }

    context 'when the score is above the threshold' do
      let(:score) { 20 }

      it 'rescues the participant' do
        expect(result.passed).to be true
        expect(result.rescued).to be true
      end
    end

    context 'when the score equals the threshold' do
      let(:score) { 15 }

      it 'rescues the participant' do
        expect(result.passed).to be true
        expect(result.rescued).to be true
      end
    end

    context 'when the score is below the threshold' do
      let(:score) { 14 }

      it 'does not rescue the participant' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the score is a float just under the threshold' do
      let(:score) { 14.99 }

      it 'does not rescue the participant' do
        expect(result.passed).to be false
      end
    end

    context 'when no threshold is configured' do
      let(:threshold) { nil }
      let(:score) { 1000 }

      it 'never rescues' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the count gate already passed' do
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1', 'HT2.q3' => '1' } }
      let(:score) { 0 }

      it 'does not consult the threshold' do
        expect(result.passed).to be true
        expect(result.rescued).to be false
      end
    end

    context 'when the payload is boolean (an OR formula)' do
      # The ticket's own example. `true >= 15` raises NoMethodError, which would
      # escape into CreateForUserSession's blanket rescue and drop the participant
      # from every chart — so the score must be type-checked, never rescued around.
      let(:payload) { '(S1.a>10) OR (S1.b>3)' }
      let(:var_values) { { 'S1.a' => '20' } }
      let(:min_answered_variables) { 2 }

      context 'and it evaluated to true' do
        let(:score) { true }

        it 'never rescues and never raises' do
          expect { result }.not_to raise_error
          expect(result.passed).to be false
          expect(result.rescued).to be false
        end
      end

      context 'and it evaluated to false' do
        let(:score) { false }

        it 'never rescues and never raises' do
          expect { result }.not_to raise_error
          expect(result.passed).to be false
        end
      end
    end

    context 'when the score is a formula error sentinel' do
      let(:score) { Chart::OTHER_FORMULA_ERROR }

      it 'never rescues' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the formula was never evaluated' do
      let(:score) { nil }

      it 'never rescues' do
        expect(result.passed).to be false
      end
    end
  end
end
