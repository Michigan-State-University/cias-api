# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustSessionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(session.id, old_session_variable, new_session_variable) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention, variable: old_session_variable, formula_update_in_progress: true) }
  let(:old_session_variable) { 'old_session_var' }
  let(:new_session_variable) { 'new_session_var' }

  before do
    allow(V1::VariableReferences::SessionService).to receive(:call)
  end

  describe '#perform' do
    context 'when session variables are identical' do
      let(:new_session_variable) { old_session_variable }

      it 'skips processing (returns early before with_formula_update_lock)' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
      end

      it 'does not change the lock state' do
        expect { perform_job }.not_to change { session.reload.formula_update_in_progress? }
      end
    end

    context 'when old session variable is blank' do
      let(:old_session_variable) { '' }

      it 'skips processing (returns early before with_formula_update_lock)' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
      end
    end

    context 'when new session variable is blank' do
      let(:new_session_variable) { '' }

      it 'skips processing (returns early before with_formula_update_lock)' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
      end
    end

    context 'when formula_update_in_progress is false (lock not held)' do
      let(:session) { create(:session, intervention: intervention, variable: old_session_variable, formula_update_in_progress: false) }

      it 'skips processing (returns early from with_formula_update_lock)' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
      end
    end

    context 'with valid session variable change and lock held' do
      it 'calls SessionService with correct arguments' do
        expect(V1::VariableReferences::SessionService).to receive(:call).with(
          session.id,
          old_session_variable,
          new_session_variable
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
