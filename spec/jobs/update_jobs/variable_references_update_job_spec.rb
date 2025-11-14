# frozen_string_literal: true

RSpec.describe UpdateJobs::VariableReferencesUpdateJob, type: :job do
  include ActiveJob::TestHelper

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:job_class) do
    Class.new(UpdateJobs::VariableReferencesUpdateJob) do
      def perform(session_id)
        with_formula_update_lock(session_id) { true }
      end
    end
  end

  describe '#with_formula_update_lock' do
    context 'when formula update lock is held (normal case)' do
      before { session.update!(formula_update_in_progress: true) }

      it 'executes the block and releases the lock after' do
        job = job_class.new
        result = job.perform(session.id)
        expect(result).to be true
        expect(session.reload.formula_update_in_progress?).to be false
      end

      it 'keeps the lock held if an error occurs (for Sidekiq retry)' do
        error_job_class = Class.new(UpdateJobs::VariableReferencesUpdateJob) do
          def perform(session_id)
            with_formula_update_lock(session_id) { raise 'Test error' }
          end
        end
        job = error_job_class.new
        expect { job.perform(session.id) }.to raise_error('Test error')
        # Lock remains held for Sidekiq to retry
        expect(session.reload.formula_update_in_progress?).to be true
      end
    end

    context 'when formula update lock is NOT held' do
      before { session.update!(formula_update_in_progress: false) }

      it 'returns early and does not execute the block' do
        block_executed = false
        job_class_with_flag = Class.new(UpdateJobs::VariableReferencesUpdateJob) do
          define_method(:perform) do |session_id|
            with_formula_update_lock(session_id) { block_executed = true }
          end
        end
        job = job_class_with_flag.new
        job.perform(session.id)
        expect(block_executed).to be false
      end

      it 'does not change the formula_update_in_progress flag' do
        job = job_class.new
        expect { job.perform(session.id) }.not_to change { session.reload.formula_update_in_progress? }
      end
    end
  end
end
