# frozen_string_literal: true

RSpec.describe UpdateJobs::VariableReferencesUpdateJob, type: :job do
  include ActiveJob::TestHelper

  let(:intervention) { create(:intervention) }
  let(:job_class) do
    Class.new(UpdateJobs::VariableReferencesUpdateJob) do
      def perform(intervention_id)
        with_formula_update_lock(intervention_id) { true }
      end
    end
  end

  describe '#with_formula_update_lock' do
    context 'when formula update is not in progress' do
      before { intervention.update!(formula_update_in_progress: false) }

      it 'sets formula_update_in_progress to true during execution and resets after' do
        job = job_class.new
        result = job.perform(intervention.id)
        expect(result).to be true
        expect(intervention.reload.formula_update_in_progress?).to be false
      end

      it 'executes the block' do
        job = job_class.new
        expect(job.perform(intervention.id)).to be true
      end

      it 'resets formula_update_in_progress even if an error occurs' do
        error_job_class = Class.new(UpdateJobs::VariableReferencesUpdateJob) do
          def perform(intervention_id)
            with_formula_update_lock(intervention_id) { raise 'Test error' }
          end
        end
        job = error_job_class.new
        expect { job.perform(intervention.id) }.to raise_error('Test error')
        expect(intervention.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when formula update is already in progress' do
      before { intervention.update!(formula_update_in_progress: true) }

      it 'returns early and does not execute the block' do
        block_executed = false
        job_class_with_flag = Class.new(UpdateJobs::VariableReferencesUpdateJob) do
          define_method(:perform) do |intervention_id|
            with_formula_update_lock(intervention_id) { block_executed = true }
          end
        end
        job = job_class_with_flag.new
        job.perform(intervention.id)
        expect(block_executed).to be false
      end

      it 'does not change the formula_update_in_progress flag' do
        job = job_class.new
        expect { job.perform(intervention.id) }.not_to change { intervention.reload.formula_update_in_progress? }
      end
    end
  end
end
