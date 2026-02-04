# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustQuestionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(question.id, old_variable_name, new_variable_name) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention, formula_update_in_progress: true) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_single, question_group: question_group) }
  let(:old_variable_name) { 'test_var' }
  let(:new_variable_name) { 'updated_var' }

  before do
    allow(V1::VariableReferences::QuestionService).to receive(:call)
  end

  describe '#perform' do
    context 'when question is not found' do
      it 'skips processing' do
        expect(V1::VariableReferences::QuestionService).not_to receive(:call)
        described_class.perform_now('non-existent-id', old_variable_name, new_variable_name)
      end
    end

    context 'when formula_update_in_progress is false (lock not held)' do
      let(:session) { create(:session, intervention: intervention, formula_update_in_progress: false) }

      it 'skips processing (returns early from with_formula_update_lock)' do
        expect(V1::VariableReferences::QuestionService).not_to receive(:call)
        perform_job
      end
    end

    context 'when formula_update_in_progress is true (lock held)' do
      context 'when variables are identical' do
        let(:new_variable_name) { old_variable_name }

        it 'does not call QuestionService' do
          expect(V1::VariableReferences::QuestionService).not_to receive(:call)
          perform_job
        end

        it 'releases the lock after execution' do
          perform_job
          expect(session.reload.formula_update_in_progress?).to be false
        end
      end

      context 'when old variable name is blank' do
        let(:old_variable_name) { '' }

        it 'does not call QuestionService' do
          expect(V1::VariableReferences::QuestionService).not_to receive(:call)
          perform_job
        end

        it 'releases the lock after execution' do
          perform_job
          expect(session.reload.formula_update_in_progress?).to be false
        end
      end

      context 'when new variable name is blank' do
        let(:new_variable_name) { '' }

        it 'does not call QuestionService' do
          expect(V1::VariableReferences::QuestionService).not_to receive(:call)
          perform_job
        end

        it 'releases the lock after execution' do
          perform_job
          expect(session.reload.formula_update_in_progress?).to be false
        end
      end

      context 'with valid variable change' do
        it 'calls QuestionService with correct arguments' do
          expect(V1::VariableReferences::QuestionService).to receive(:call).with(
            question.id,
            old_variable_name,
            new_variable_name
          )
          perform_job
        end

        it 'releases the lock after execution' do
          perform_job
          expect(session.reload.formula_update_in_progress?).to be false
        end
      end
    end
  end
end
