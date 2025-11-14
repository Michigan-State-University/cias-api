# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustQuestionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(question.id, old_variable_name, new_variable_name) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_single, question_group: question_group) }
  let(:old_variable_name) { 'test_var' }
  let(:new_variable_name) { 'updated_var' }

  describe '#perform' do
    before do
      # Set the lock as held (simulating that the service acquired it)
      session.update!(formula_update_in_progress: true)
    end

    context 'when variables are identical' do
      let(:new_variable_name) { old_variable_name }

      it 'skips processing but still releases the lock' do
        expect(V1::VariableReferences::QuestionService).not_to receive(:call)
        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when old variable name is blank' do
      let(:old_variable_name) { '' }

      it 'skips processing but still releases the lock' do
        expect(V1::VariableReferences::QuestionService).not_to receive(:call)
        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when new variable name is blank' do
      let(:new_variable_name) { '' }

      it 'skips processing but still releases the lock' do
        expect(V1::VariableReferences::QuestionService).not_to receive(:call)
        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end

    context 'with valid variable change' do
      it 'calls QuestionService with correct arguments and releases the lock' do
        expect(V1::VariableReferences::QuestionService).to receive(:call).with(question.id, old_variable_name, new_variable_name)

        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end
  end
end
