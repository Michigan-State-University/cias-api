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
    context 'when variables are identical' do
      let(:new_variable_name) { old_variable_name }

      it 'skips processing when variables are identical' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when old variable name is blank' do
      let(:old_variable_name) { '' }

      it 'skips processing when old variable name is blank' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when new variable name is blank' do
      let(:new_variable_name) { '' }

      it 'skips processing when new variable name is blank' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'with valid variable change' do
      it 'calls QuestionService with correct arguments' do
        expect(V1::VariableReferences::QuestionService).to receive(:call).with(question.id, old_variable_name, new_variable_name)
        expect_any_instance_of(described_class).to receive(:with_formula_update_lock).with(question.session.intervention_id).and_call_original

        perform_job
      end
    end
  end
end
