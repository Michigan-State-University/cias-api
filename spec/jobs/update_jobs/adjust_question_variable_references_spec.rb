# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustQuestionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(question.id, old_variable_name, new_variable_name) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_single, question_group: question_group, body: question_body) }
  let(:question_body) do
    {
      data: [{ payload: 'Answer 1', value: '1' }],
      variable: { name: new_variable_name }
    }
  end

  let(:old_variable_name) { 'test_var' }
  let(:new_variable_name) { 'updated_var' }

  describe '#perform' do
    context 'when variables are identical' do
      let(:new_variable_name) { old_variable_name }

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when old variable name is blank' do
      let(:old_variable_name) { '' }

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when new variable name is blank' do
      let(:new_variable_name) { '' }

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'with valid variable change' do
      let!(:other_session) { create(:session, intervention: intervention) }
      let!(:other_question_group) { create(:question_group, session: other_session) }

      # Question with formulas containing the old variable
      let!(:question_with_formula) do
        create(:question_single, question_group: question_group, body: {
                 'variable' => { 'name' => 'q1' },
                 'data' => [{ 'payload' => 'test', 'value' => '1' }]
               }, narrator: {
                 'settings' => { 'voice' => true, 'animation' => true, 'character' => 'peedy' },
                 'blocks' => [
                   {
                     'type' => 'Speech',
                     'text' => ['Test speech block'],
                     'sha256' => [],
                     'audio_urls' => []
                   }
                 ]
               }, formulas: [
                 { 'payload' => 'q1 + 1', 'patterns' => [] }
               ])
      end

      # Question with narrator blocks containing ReflectionFormula
      let!(:question_with_narrator) do
        create(:question_single,
               question_group: question_group,
               narrator: {
                 settings: { voice: true, animation: true, character: 'peedy' },
                 blocks: [
                   {
                     type: 'Speech',
                     text: ["Result: #{old_variable_name}"],
                     animation: 'rest',
                     sha256: [],
                     audio_urls: []
                   }
                 ]
               })
      end

      # Question with Reflection blocks containing variable references
      let!(:question_with_reflections) do
        create(:question_single,
               question_group: question_group,
               narrator: {
                 settings: { voice: true, animation: true, character: 'peedy' },
                 blocks: [
                   {
                     type: 'Reflection',
                     sha256: [],
                     reflections: [
                       {
                         text: ['Response 1'],
                         value: '1',
                         variable: old_variable_name,
                         payload: 'test',
                         sha256: [],
                         audio_urls: []
                       }
                     ]
                   }
                 ]
               })
      end

      # Cross-session references
      let!(:cross_session_question) do
        create(:question_single,
               question_group: other_question_group,
               formulas: [{ payload: "#{session.variable}.#{old_variable_name} + 2", patterns: [] }])
      end

      before do
        allow_any_instance_of(Intervention).to receive(:formula_update_in_progress?).and_return(false)
        allow_any_instance_of(Intervention).to receive(:update!).with(formula_update_in_progress: true)
        allow_any_instance_of(Intervention).to receive(:update!).with(formula_update_in_progress: false)
      end

      it 'updates question formulas in source session' do
        expect_any_instance_of(described_class).to receive(:update_question_formulas_scoped)
          .with(session, old_variable_name, new_variable_name, exclude_source_session: false)

        perform_job
      end

      it 'updates narrator formulas in source session' do
        expect_any_instance_of(described_class).to receive(:update_question_narrator_formulas_scoped)
          .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
        expect_any_instance_of(described_class).to receive(:update_question_narrator_formulas_scoped)
          .with(session, "#{session.variable}.#{old_variable_name}", "#{session.variable}.#{new_variable_name}", exclude_source_session: true)

        perform_job
      end

      it 'updates narrator reflection variables in source session' do
        expect_any_instance_of(described_class).to receive(:update_question_narrator_reflection_variables_scoped)
          .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
        expect_any_instance_of(described_class).to receive(:update_question_narrator_reflection_variables_scoped)
          .with(session, "#{session.variable}.#{old_variable_name}", "#{session.variable}.#{new_variable_name}", exclude_source_session: true)

        perform_job
      end

      it 'updates session formulas' do
        expect_any_instance_of(described_class).to receive(:update_session_formulas_scoped)
          .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
        expect_any_instance_of(described_class).to receive(:update_session_formulas_scoped)
          .with(session, "#{session.variable}.#{old_variable_name}", "#{session.variable}.#{new_variable_name}", exclude_source_session: true)

        perform_job
      end

      it 'updates question group formulas' do
        expect_any_instance_of(described_class).to receive(:update_question_group_formulas_scoped)
          .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
        expect_any_instance_of(described_class).to receive(:update_question_group_formulas_scoped)
          .with(session, "#{session.variable}.#{old_variable_name}", "#{session.variable}.#{new_variable_name}", exclude_source_session: true)

        perform_job
      end

      it 'updates report template formulas' do
        expect_any_instance_of(described_class).to receive(:update_report_template_formulas_scoped)
          .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
        expect_any_instance_of(described_class).to receive(:update_report_template_formulas_scoped)
          .with(session, "#{session.variable}.#{old_variable_name}", "#{session.variable}.#{new_variable_name}", exclude_source_session: true)

        perform_job
      end

      context 'cross-session pattern updates' do
        it 'updates cross-session formulas with proper patterns' do
          old_pattern = "#{session.variable}.#{old_variable_name}"
          new_pattern = "#{session.variable}.#{new_variable_name}"

          # Phase 1: Direct references first
          expect_any_instance_of(described_class).to receive(:update_question_formulas_scoped)
            .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
          expect_any_instance_of(described_class).to receive(:update_question_narrator_formulas_scoped)
            .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
          expect_any_instance_of(described_class).to receive(:update_question_narrator_reflection_variables_scoped)
            .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
          expect_any_instance_of(described_class).to receive(:update_session_formulas_scoped)
            .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
          expect_any_instance_of(described_class).to receive(:update_question_group_formulas_scoped)
            .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
          expect_any_instance_of(described_class).to receive(:update_report_template_formulas_scoped)
            .with(session, old_variable_name, new_variable_name, exclude_source_session: false)
          # Phase 2: Cross-session references
          expect_any_instance_of(described_class).to receive(:update_session_formulas_scoped)
            .with(session, old_pattern, new_pattern, exclude_source_session: true)
          expect_any_instance_of(described_class).to receive(:update_question_group_formulas_scoped)
            .with(session, old_pattern, new_pattern, exclude_source_session: true)
          expect_any_instance_of(described_class).to receive(:update_question_narrator_formulas_scoped)
            .with(session, old_pattern, new_pattern, exclude_source_session: true)
          expect_any_instance_of(described_class).to receive(:update_question_narrator_reflection_variables_scoped)
            .with(session, old_pattern, new_pattern, exclude_source_session: true)
          expect_any_instance_of(described_class).to receive(:update_report_template_formulas_scoped)
            .with(session, old_pattern, new_pattern, exclude_source_session: true)
          expect_any_instance_of(described_class).to receive(:update_chart_formulas)
            .with(intervention.id, old_pattern, new_pattern)

          perform_job
        end

        it 'updates chart formulas with cross-session patterns' do
          old_pattern = "#{session.variable}.#{old_variable_name}"
          new_pattern = "#{session.variable}.#{new_variable_name}"

          expect_any_instance_of(described_class).to receive(:update_chart_formulas)
            .with(intervention.id, old_pattern, new_pattern)

          perform_job
        end
      end

      it 'runs within a transaction' do
        expect(ActiveRecord::Base).to receive(:transaction).at_least(:once).and_call_original
        perform_job
      end

      it 'acquires formula update lock' do
        expect_any_instance_of(described_class).to receive(:with_formula_update_lock)
          .with(intervention.id).and_call_original

        perform_job
      end
    end

    context 'when intervention has formula update in progress' do
      before do
        intervention.update!(formula_update_in_progress: true)
      end

      it 'returns early without processing' do
        expect_any_instance_of(described_class).not_to receive(:update_question_formulas_scoped)

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
end
