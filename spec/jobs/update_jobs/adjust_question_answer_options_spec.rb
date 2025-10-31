# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustQuestionAnswerOptions, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(question_id, changed_answer_values) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_multiple, question_group: question_group) }
  let(:question_id) { question.id }
  let(:changed_answer_values) { { 'var1' => { 'old_payload' => 'new_payload' } } }

  before do
    stub_const('V1::VariableReferences::AnswerOptionsService', class_double(V1::VariableReferences::AnswerOptionsService, call: true))
  end

  describe '#perform' do
    context 'when changed_answer_values is blank' do
      let(:changed_answer_values) { {} }

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when changed_answer_values is nil' do
      let(:changed_answer_values) { nil }

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when question is not found' do
      let(:question_id) { 'non-existent-id' }

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when question has no intervention_id' do
      before do
        allow(Question).to receive(:find_by).with(id: question_id).and_return(question)
        allow(question).to receive(:session).and_return(nil)
      end

      it 'skips processing' do
        expect(V1::VariableReferences::AnswerOptionsService).not_to receive(:call)
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'with valid data' do
      it 'calls AnswerOptionsService with correct arguments and a lock' do
        expect(V1::VariableReferences::AnswerOptionsService).to receive(:call).with(question.id, changed_answer_values)
        expect_any_instance_of(described_class).to receive(:with_formula_update_lock).with(question.session.intervention_id).and_call_original

        perform_job
      end
    end
  end
end
