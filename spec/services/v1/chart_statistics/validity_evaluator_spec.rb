# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::ValidityEvaluator do
  subject(:result) { described_class.call(chart, var_values, score, matched_pattern: matched_pattern) }

  let(:payload) { 'HT2.q1 + HT2.q2 + HT2.q3 + HT2.q4' }
  let(:min_answered_variables) { 3 }
  let(:rescue_enabled) { false }
  let(:score) { nil }
  let(:matched_pattern) { nil }
  let(:var_values) { {} }
  let(:positive_pattern) { { 'match' => '>=10', 'label' => 'Positive', 'color' => '#C766EA' } }
  let(:formula) do
    {
      'payload' => payload,
      'patterns' => [positive_pattern],
      'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
      'min_answered_variables' => min_answered_variables,
      'positive_despite_missing_data' => rescue_enabled
    }
  end
  let(:chart) { build(:chart, formula: formula) }

  describe 'class-level readers' do
    it 'reports the gate as enabled and exposes both settings' do
      expect(described_class.enabled?(chart)).to be true
      expect(described_class.min_answered_variables(chart)).to eq(3)
      expect(described_class.rescue_enabled?(chart)).to be false
    end

    context 'with the rescue turned on' do
      let(:rescue_enabled) { true }

      it 'reports the rescue as enabled' do
        expect(described_class.rescue_enabled?(chart)).to be true
      end
    end

    context 'with a legacy formula that carries neither key' do
      let(:formula) do
        {
          'payload' => payload,
          'patterns' => [positive_pattern],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' }
        }
      end

      it 'reports the gate as disabled without raising' do
        expect(described_class.enabled?(chart)).to be false
        expect(described_class.min_answered_variables(chart)).to eq(0)
        expect(described_class.rescue_enabled?(chart)).to be false
      end
    end

    context 'with a leftover numeric threshold key and no boolean key' do
      # The numeric key predates this feature's deploy and is never read.
      let(:formula) do
        {
          'payload' => payload,
          'patterns' => [positive_pattern],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables,
          'positive_despite_missing_threshold' => 15
        }
      end

      it 'reads the rescue as off' do
        expect(described_class.rescue_enabled?(chart)).to be false
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
          'patterns' => [positive_pattern],
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

      context 'and the rescue is on with a matched case' do
        let(:rescue_enabled) { true }
        let(:score) { 20 }
        let(:matched_pattern) { positive_pattern }

        it 'is still rescued' do
          expect(result.passed).to be true
          expect(result.rescued).to be true
        end
      end
    end
  end

  describe 'the case-match rescue' do
    let(:var_values) { { 'HT2.q1' => '1' } }
    let(:rescue_enabled) { true }

    context 'when the 0-filled score matched an explicit case' do
      let(:score) { 20 }
      let(:matched_pattern) { positive_pattern }

      it 'rescues the participant' do
        expect(result.passed).to be true
        expect(result.rescued).to be true
      end
    end

    context 'when the score fell to the default category (no explicit case matched)' do
      let(:score) { 9 }
      let(:matched_pattern) { nil }

      it 'never rescues — a rescued participant cannot land in the default category' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the matched case carries the default category label' do
      # Aggregation buckets purely by label string (pie_chart.rb:29-33), so a case whose
      # label duplicates the default's would rescue the participant INTO the default
      # category as rendered. Structural identity is not enough.
      let(:score) { 20 }
      let(:matched_pattern) { { 'match' => '>=10', 'label' => 'Negative', 'color' => '#C766EA' } }

      it 'never rescues — the rendered category would be the default one' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the rescue is off' do
      let(:rescue_enabled) { false }
      let(:score) { 20 }
      let(:matched_pattern) { positive_pattern }

      it 'never rescues even though the score matched a case' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the boolean key is absent (legacy chart)' do
      let(:formula) do
        {
          'payload' => payload,
          'patterns' => [positive_pattern],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables
        }
      end
      let(:score) { 20 }
      let(:matched_pattern) { positive_pattern }

      it 'reads the rescue as off' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when only the leftover numeric threshold key is present' do
      # Never deployed; a leftover numeric key must read as rescue-off.
      let(:formula) do
        {
          'payload' => payload,
          'patterns' => [positive_pattern],
          'default_pattern' => { 'label' => 'Negative', 'color' => '#E2B1F4' },
          'min_answered_variables' => min_answered_variables,
          'positive_despite_missing_threshold' => 1
        }
      end
      let(:score) { 20 }
      let(:matched_pattern) { positive_pattern }

      it 'never rescues' do
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    context 'when the count gate already passed' do
      let(:var_values) { { 'HT2.q1' => '1', 'HT2.q2' => '1', 'HT2.q3' => '1' } }
      let(:score) { 0 }
      # A Hash here is what makes the assertion falsifiable: without the count-gate
      # short-circuit, rescue-on + a matched case would report rescued.
      let(:matched_pattern) { positive_pattern }

      it 'does not consult the rescue' do
        expect(result.passed).to be true
        expect(result.rescued).to be false
      end
    end

    context 'when the payload is boolean (an OR formula) and matched an explicit case' do
      # Deliberate behaviour change from the numeric threshold: the pattern match
      # replaced the score arithmetic, so a boolean chart matching `=true` is
      # rescuable and nothing ever compares the score numerically.
      let(:payload) { '(S1.a>10) OR (S1.b>3)' }
      let(:var_values) { { 'S1.a' => '20' } }
      let(:min_answered_variables) { 2 }
      let(:score) { true }
      let(:matched_pattern) { { 'match' => '=true', 'label' => 'Flagged', 'color' => '#C766EA' } }

      it 'rescues without raising' do
        expect { result }.not_to raise_error
        expect(result.passed).to be true
        expect(result.rescued).to be true
      end
    end

    context 'when the payload is boolean and fell to the default' do
      let(:payload) { '(S1.a>10) OR (S1.b>3)' }
      let(:var_values) { { 'S1.a' => '2' } }
      let(:min_answered_variables) { 2 }
      let(:score) { false }
      let(:matched_pattern) { nil }

      it 'never rescues and never raises' do
        expect { result }.not_to raise_error
        expect(result.passed).to be false
        expect(result.rescued).to be false
      end
    end

    # The error sentinels were pinned on the score before the signature change;
    # that protection now applies to `matched_pattern`: only a real pattern Hash
    # rescues. `FormulaInterface#calculate` returns the truthy
    # sentinel STRINGS below on evaluation errors, and an unfiltered caller must
    # never be able to turn "formula errored" into "rescued".
    context 'when matched_pattern is not a pattern hash' do
      let(:score) { 20 }

      [Chart::ZERO_DIVISION_ERROR, Chart::OTHER_FORMULA_ERROR, true, 'Positive'].each do |non_hash|
        context "with #{non_hash.inspect}" do
          let(:matched_pattern) { non_hash }

          it 'never rescues' do
            expect(result.passed).to be false
            expect(result.rescued).to be false
          end
        end
      end
    end

    context 'when the formula was never evaluated' do
      let(:score) { nil }
      let(:matched_pattern) { nil }

      it 'never rescues' do
        expect(result.passed).to be false
      end
    end
  end
end
