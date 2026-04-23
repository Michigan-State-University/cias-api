# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::VariableAnswersValidator do
  subject(:call) { described_class.call(intervention, participant_params_list) }

  let(:intervention) { create(:intervention) }
  let(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
  let(:question_group) { create(:question_group, session: ra_session) }

  def single_question(variable:, values:)
    create(:question_single,
           question_group: question_group,
           body: {
             'data' => values.each_with_index.map { |v, i| { 'payload' => "Option #{i + 1}", 'value' => v } },
             'variable' => { 'name' => variable }
           })
  end

  def number_question(variable:)
    create(:question_number,
           question_group: question_group,
           body: { 'data' => [{ 'payload' => 'Score' }], 'variable' => { 'name' => variable } })
  end

  def date_question(variable:)
    create(:question_date,
           question_group: question_group,
           body: { 'data' => [{ 'payload' => 'Visit date' }], 'variable' => { 'name' => variable } })
  end

  def multiple_question(variable:)
    create(:question_multiple,
           question_group: question_group,
           body: {
             'data' => [{ 'payload' => 'Opt', 'variable' => { 'name' => variable, 'value' => '1' } }]
           })
  end

  # Build a participant row hash. Mirrors the shape the controller hands the
  # validator: the permitted participant params hash with an optional
  # `:variable_answers` entry.
  def row(variable_answers = nil)
    variable_answers ? { variable_answers: variable_answers } : {}
  end

  describe 'no participant has variable_answers' do
    let(:participant_params_list) { [row, row(nil), row({})] }

    it 'returns nil without raising (nothing to validate)' do
      expect(call).to be_nil
    end

    it 'does not hit the DB looking for an RA session' do
      expect(intervention.sessions).not_to receive(:find_by)
      call
    end
  end

  describe 'no RA session on intervention' do
    let(:intervention) { create(:intervention) }
    let(:participant_params_list) { [row('s1.var1' => '1')] }

    it 'raises ComplexException with code ra_session_missing' do
      expect { call }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to eq([{ code: 'ra_session_missing' }])
      end
    end
  end

  describe 'RA session with no answerable questions' do
    before { ra_session } # ensure it exists (has a question_group but no questions)

    let(:participant_params_list) { [row('s1.var1' => '1')] }

    it 'raises ComplexException with code ra_session_has_no_answerable_questions' do
      expect { call }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to eq([{ code: 'ra_session_has_no_answerable_questions' }])
      end
    end
  end

  describe 'Single question' do
    before { single_question(variable: 'mood', values: %w[1 2 3 4 5]) }

    context 'with a valid option value' do
      let(:participant_params_list) { [row('s1.mood' => '3')] }

      it 'returns nil (no errors)' do
        expect(call).to be_nil
      end
    end

    context 'with an out-of-options value' do
      let(:participant_params_list) { [row('s1.mood' => '999')] }

      it 'raises with code value_not_in_options and valid_values context' do
        expect { call }.to raise_error(ComplexException) do |exc|
          errors = exc.additional_information[:errors]
          expect(errors).to include(a_hash_including(row: 0, field: 's1.mood', code: 'value_not_in_options', valid_values: %w[1 2 3 4 5]))
        end
      end

      it 'does not include the raw value 999 anywhere in the error payload (HIPAA)' do
        expect { call }.to raise_error(ComplexException) do |exc|
          serialised = exc.additional_information[:errors].to_s
          expect(serialised).not_to include('999')
        end
      end
    end

    context 'with whitespace around the value' do
      let(:participant_params_list) { [row('s1.mood' => ' 3 ')] }

      it 'strips and accepts' do
        expect(call).to be_nil
      end
    end

    context 'with blank value' do
      let(:participant_params_list) { [row('s1.mood' => '')] }

      it 'raises with code value_blank' do
        expect { call }.to raise_error(ComplexException) do |exc|
          expect(exc.additional_information[:errors]).to include(a_hash_including(code: 'value_blank'))
        end
      end
    end

    context 'with whitespace-only value' do
      let(:participant_params_list) { [row('s1.mood' => '   ')] }

      it 'raises with code value_blank' do
        expect { call }.to raise_error(ComplexException) do |exc|
          expect(exc.additional_information[:errors]).to include(a_hash_including(code: 'value_blank'))
        end
      end
    end
  end

  describe 'Number question' do
    before { number_question(variable: 'score') }

    it 'accepts numeric values' do
      expect(described_class.call(intervention, [row('s1.score' => '42')])).to be_nil
    end

    it 'accepts scientific notation' do
      expect(described_class.call(intervention, [row('s1.score' => '1.5e3')])).to be_nil
    end

    it 'rejects non-numeric input with code value_not_a_number' do
      expect { described_class.call(intervention, [row('s1.score' => 'not-a-number')]) }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to include(a_hash_including(field: 's1.score', code: 'value_not_a_number'))
      end
    end
  end

  describe 'Date question' do
    before { date_question(variable: 'visit_date') }

    it 'accepts ISO date strings' do
      expect(described_class.call(intervention, [row('s1.visit_date' => '2026-03-15')])).to be_nil
    end

    it 'rejects unparseable input with code value_not_a_date' do
      expect { described_class.call(intervention, [row('s1.visit_date' => 'not-a-date')]) }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to include(a_hash_including(field: 's1.visit_date', code: 'value_not_a_date'))
      end
    end
  end

  describe 'session variable mismatch' do
    before { single_question(variable: 'mood', values: %w[1 2 3]) }

    let(:participant_params_list) { [row('wrong_session.mood' => '1')] }

    it 'raises with code session_variable_mismatch' do
      expect { call }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to include(a_hash_including(field: 'wrong_session.mood', code: 'session_variable_mismatch'))
      end
    end
  end

  describe 'unknown question variable' do
    before { single_question(variable: 'mood', values: %w[1 2 3]) }

    let(:participant_params_list) { [row('s1.nonexistent' => '1')] }

    it 'raises with code unknown_question_variable' do
      expect { call }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to include(a_hash_including(field: 's1.nonexistent', code: 'unknown_question_variable'))
      end
    end
  end

  describe 'unsupported question type (Multiple)' do
    before { multiple_question(variable: 'picks') }

    let(:participant_params_list) { [row('s1.picks' => '1')] }

    it 'raises with code unsupported_question_type and the offending type' do
      expect { call }.to raise_error(ComplexException) do |exc|
        expect(exc.additional_information[:errors]).to include(a_hash_including(field: 's1.picks', code: 'unsupported_question_type', question_type: 'Question::Multiple'))
      end
    end
  end

  describe 'whitespace tolerance in CSV header (the key)' do
    before { single_question(variable: 'mood', values: %w[1 2 3]) }

    let(:participant_params_list) { [row(' s1.mood ' => '1')] }

    it 'accepts the entry by stripping the key halves' do
      expect(call).to be_nil
    end
  end

  describe 'per-participant errors accumulate across multiple rows' do
    before { single_question(variable: 'mood', values: %w[1 2 3]) }

    # Index 1 has no variable_answers — error rows should be tagged 0 and 2.
    let(:participant_params_list) do
      [row('s1.mood' => '999'), row, row('s1.mood' => 'also_bad')]
    end

    it 'raises once with errors tagged by row index' do
      expect { call }.to raise_error(ComplexException) do |exc|
        rows = exc.additional_information[:errors].map { |e| e[:row] }
        expect(rows).to contain_exactly(0, 2)
      end
    end
  end

  describe 'HIPAA — no raw values in error payloads' do
    before { single_question(variable: 'mood', values: %w[1 2 3 4 5]) }

    let(:participant_params_list) { [row('s1.mood' => 'SENSITIVE_VALUE_XYZ')] }

    it 'errors list does not include the raw value' do
      expect { call }.to raise_error(ComplexException) do |exc|
        serialised = exc.additional_information[:errors].to_s
        expect(serialised).not_to include('SENSITIVE_VALUE_XYZ')
      end
    end

    it 'ComplexException.message does not include the raw value' do
      expect { call }.to raise_error(ComplexException) do |exc|
        expect(exc.message).not_to include('SENSITIVE_VALUE_XYZ')
      end
    end
  end
end
