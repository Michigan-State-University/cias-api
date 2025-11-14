# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustQuestionAnswerOptionsReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) do
    described_class.perform_now(
      question_id,
      changed_answer_values,
      new_answer_options,
      deleted_answer_options,
      grid_columns
    )
  end

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_multiple, question_group: question_group) }
  let(:question_id) { question.id }
  let(:changed_answer_values) { { 'var1' => { 'old_payload' => 'new_payload' } } }
  let(:new_answer_options) { {} }
  let(:deleted_answer_options) { {} }
  let(:grid_columns) { { changed: {}, new: {}, deleted: {} } }

  before do
    allow(V1::VariableReferences::AnswerOptionsService).to receive(:call).and_return(true)
  end

  describe '#perform' do
    context 'when all parameters are blank' do
      let(:changed_answer_values) { {} }

      it 'skips processing (no lock involved)' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        perform_job
      end
    end

    context 'when changed_answer_values is nil' do
      let(:changed_answer_values) { nil }

      it 'skips processing (no lock involved)' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        perform_job
      end
    end

    context 'when question is not found' do
      let(:question_id) { 'non-existent-id' }

      it 'skips processing (no lock involved)' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        perform_job
      end
    end

    context 'with valid data' do
      it 'calls AnswerOptionsService with correct arguments and a lock' do
        expect(V1::VariableReferences::AnswerOptionsService).to receive(:call).with(
          question.id,
          changed_answer_values,
          new_answer_options,
          deleted_answer_options,
          grid_columns
        )
        expect_any_instance_of(described_class).to receive(:with_formula_update_lock).with(question.session.intervention_id).and_call_original

        perform_job
      end
    end
  end
end
