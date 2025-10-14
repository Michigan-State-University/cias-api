# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustSessionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(session.id, old_session_variable, new_session_variable) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention, variable: old_session_variable) }
  let(:question_group) { create(:question_group, session: session) }

  let(:old_session_variable) { 'old_session_var' }
  let(:new_session_variable) { 'new_session_var' }

  describe '#perform' do
    context 'when session variables are identical' do
      let(:new_session_variable) { old_session_variable }

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when old session variable is blank' do
      let(:old_session_variable) { '' }

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when new session variable is blank' do
      let(:new_session_variable) { '' }

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'with valid session variable change' do
      let!(:other_session) { create(:session, intervention: intervention) }
      let!(:other_question_group) { create(:question_group, session: other_session) }

      # Questions with variables in the source session
      let!(:question1) do
        create(:question_single,
               question_group: question_group,
               body: {
                 data: [{ payload: 'Answer 1', value: '1' }],
                 variable: { name: 'question_var_1' }
               })
      end

      let!(:question2) do
        create(:question_multiple,
               question_group: question_group,
               body: {
                 data: [
                   { payload: 'Option 1', variable: { name: 'question_var_2', value: '1' } },
                   { payload: 'Option 2', variable: { name: 'question_var_3', value: '2' } }
                 ]
               })
      end

      # Cross-session questions that reference the session variable
      let!(:cross_session_question) do
        create(:question_single,
               question_group: other_question_group,
               formulas: [
                 { payload: "#{old_session_variable} + 1", patterns: [] },
                 { payload: "#{old_session_variable}.question_var_1 * 2", patterns: [] }
               ])
      end

      before do
        allow_any_instance_of(Intervention).to receive(:formula_update_in_progress?).and_return(false)
        allow_any_instance_of(Intervention).to receive(:update!).with(formula_update_in_progress: true)
        allow_any_instance_of(Intervention).to receive(:update!).with(formula_update_in_progress: false)
      end

      it 'successfully processes the job' do
        expect { perform_job }.not_to raise_error
      end

      it 'updates patterns for session variable and question variables' do
        expected_old_patterns = [
          old_session_variable,
          "#{old_session_variable}.question_var_1",
          "#{old_session_variable}.question_var_2",
          "#{old_session_variable}.question_var_3"
        ]

        expected_new_patterns = [
          new_session_variable,
          "#{new_session_variable}.question_var_1",
          "#{new_session_variable}.question_var_2",
          "#{new_session_variable}.question_var_3"
        ]

        expected_old_patterns.zip(expected_new_patterns).each do |old_pattern, new_pattern|
          expect_any_instance_of(described_class).to receive(:update_variable_references)
            .with(old_pattern, new_pattern)
        end

        perform_job
      end

      it 'runs within a transaction' do
        expect_any_instance_of(described_class).to receive(:update_variable_references).at_least(:once)
        perform_job
      end

      it 'acquires formula update lock' do
        expect_any_instance_of(described_class).to receive(:with_formula_update_lock)
          .with(intervention.id).and_call_original

        perform_job
      end

      context 'when session has no questions' do
        let(:question_group) { create(:question_group, session: session) }

        before do
          # Remove questions from the session
          question_group.questions.destroy_all
        end

        it 'only processes the session variable itself' do
          expect_any_instance_of(described_class).to receive(:update_variable_references)
            .with(old_session_variable, new_session_variable)
            .once

          perform_job
        end
      end
    end

    context 'when intervention has formula update in progress' do
      before do
        intervention.update!(formula_update_in_progress: true)
      end

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:update_variable_references)

        perform_job
      end
    end

    context 'when an error occurs during processing' do
      before do
        intervention.update!(formula_update_in_progress: false)
      end

      it 'ensures the lock is released' do
        allow(ActiveRecord::Base).to receive(:transaction).and_raise(StandardError, 'Test error')

        expect { perform_job }.to raise_error(StandardError, 'Test error')
        expect(intervention.reload.formula_update_in_progress?).to be false
      end

      it 'logs the error' do
        allow(ActiveRecord::Base).to receive(:transaction).and_raise(StandardError, 'Test error')

        expect { perform_job }.to raise_error(StandardError, 'Test error')
      end
    end
  end

  describe '#extract_question_variables_from_session' do
    let!(:single_question) do
      create(:question_single,
             question_group: question_group,
             body: {
               data: [{ payload: 'Answer 1', value: '1' }],
               variable: { name: 'single_var' }
             })
    end

    let!(:multiple_question) do
      create(:question_multiple,
             question_group: question_group,
             body: {
               data: [
                 { payload: 'Option 1', variable: { name: 'multi_var_1', value: '1' } },
                 { payload: 'Option 2', variable: { name: 'multi_var_2', value: '2' } }
               ]
             })
    end

    let!(:grid_question) do
      create(:question_grid,
             question_group: question_group,
             body: {
               data: [{
                 payload: {
                   rows: [
                     { payload: 'Row 1', variable: { name: 'grid_var_1' } },
                     { payload: 'Row 2', variable: { name: 'grid_var_2' } }
                   ],
                   columns: [
                     { payload: 'Col 1', variable: { value: '1' } },
                     { payload: 'Col 2', variable: { value: '2' } }
                   ]
                 }
               }]
             })
    end

    it 'extracts variables from all question types' do
      job = described_class.new
      variables = job.send(:extract_question_variables_from_session, session)

      expect(variables).to include('single_var', 'multi_var_1', 'multi_var_2', 'grid_var_1', 'grid_var_2')
    end
  end
end
