# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustSessionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(session.id, old_session_variable, new_session_variable) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention, variable: old_session_variable) }
  let(:old_session_variable) { 'old_session_var' }
  let(:new_session_variable) { 'new_session_var' }

  describe '#perform' do
    context 'when session variables are identical' do
      let(:new_session_variable) { old_session_variable }

      it 'skips processing when session variables are identical' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when old session variable is blank' do
      let(:old_session_variable) { '' }

      it 'skips processing when old session variable is blank' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'when new session variable is blank' do
      let(:new_session_variable) { '' }

      it 'skips processing when new session variable is blank' do
        expect_any_instance_of(described_class).not_to receive(:with_formula_update_lock)
        perform_job
      end
    end

    context 'with valid session variable change' do
      it 'calls SessionService with correct arguments' do
        expect(V1::VariableReferences::SessionService).to receive(:call).with(session.id, old_session_variable, new_session_variable)
        expect_any_instance_of(described_class).to receive(:with_formula_update_lock).with(session.intervention_id).and_call_original

        perform_job
      end
    end
  end
end
