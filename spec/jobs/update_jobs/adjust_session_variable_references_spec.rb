# frozen_string_literal: true

RSpec.describe UpdateJobs::AdjustSessionVariableReferences, type: :job do
  include ActiveJob::TestHelper

  subject(:perform_job) { described_class.perform_now(session.id, old_session_variable, new_session_variable) }

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention, variable: old_session_variable) }
  let(:old_session_variable) { 'old_session_var' }
  let(:new_session_variable) { 'new_session_var' }

  describe '#perform' do
    before do
      # Set the lock as held (simulating that the service acquired it)
      session.update!(formula_update_in_progress: true)
    end

    context 'when session variables are identical' do
      let(:new_session_variable) { old_session_variable }

      it 'skips processing but still releases the lock' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when old session variable is blank' do
      let(:old_session_variable) { '' }

      it 'skips processing but still releases the lock' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when new session variable is blank' do
      let(:new_session_variable) { '' }

      it 'skips processing but still releases the lock' do
        expect(V1::VariableReferences::SessionService).not_to receive(:call)
        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end

    context 'with valid session variable change' do
      it 'calls SessionService with correct arguments and releases the lock' do
        expect(V1::VariableReferences::SessionService).to receive(:call).with(session.id, old_session_variable, new_session_variable)

        perform_job
        expect(session.reload.formula_update_in_progress?).to be false
      end
    end
  end
end
