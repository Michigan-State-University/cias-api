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
  let(:changed_answer_values) { [{ 'variable' => 'var1', 'old_payload' => 'old', 'new_payload' => 'new', 'value' => '1' }] }
  let(:new_answer_options) { [] }
  let(:deleted_answer_options) { [] }
  let(:grid_columns) { { changed: {}, new: {}, deleted: {} } }

  before do
    allow(V1::VariableReferences::AnswerOptionsService).to receive(:call)
  end

  describe '#perform' do
    context 'when all inputs are blank' do
      let(:changed_answer_values) { [] }
      let(:new_answer_options) { [] }
      let(:deleted_answer_options) { [] }
      let(:grid_columns) { { changed: {}, new: {}, deleted: {} } }

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        perform_job
      end
    end

    context 'when changed_answer_values is nil' do
      let(:changed_answer_values) { nil }
      let(:new_answer_options) { nil }
      let(:deleted_answer_options) { nil }

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        perform_job
      end
    end

    context 'when question is not found' do
      let(:question_id) { 'non-existent-id' }

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        perform_job
      end
    end

    context 'with valid data' do
      it 'calls AnswerOptionsService with correct arguments' do
        expect(V1::VariableReferences::AnswerOptionsService).to receive(:call).with(
          question.id,
          changed_answer_values,
          new_answer_options,
          deleted_answer_options,
          { changed: {}, new: {}, deleted: {} }
        )

        perform_job
      end
    end

    context 'with grid column changes' do
      let(:changed_answer_values) { [] }
      let(:grid_columns) { { changed: { 'a' => { 'old' => 'Col A', 'new' => 'Col A Updated' } }, new: {}, deleted: {} } }

      it 'calls AnswerOptionsService with grid column changes' do
        expect(V1::VariableReferences::AnswerOptionsService).to receive(:call).with(
          question.id,
          [],
          [],
          [],
          { changed: { 'a' => { 'old' => 'Col A', 'new' => 'Col A Updated' } }, new: {}, deleted: {} }
        )

        perform_job
      end
    end
  end
end
