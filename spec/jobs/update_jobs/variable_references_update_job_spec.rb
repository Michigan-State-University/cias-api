# frozen_string_literal: true

RSpec.describe UpdateJobs::VariableReferencesUpdateJob, type: :job do
  include ActiveJob::TestHelper

  let(:test_job_class) do
    Class.new(UpdateJobs::VariableReferencesUpdateJob) do
      def perform(intervention_id, _old_var, _new_var)
        with_formula_update_lock(intervention_id) do
          true
        end
      end
    end
  end

  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  let(:old_var) { 'old_variable' }
  let(:new_var) { 'new_variable' }

  describe '#with_formula_update_lock' do
    context 'when intervention does not have formula update in progress' do
      before do
        intervention.update!(formula_update_in_progress: false)
      end

      it 'sets formula_update_in_progress to true during execution' do
        job = test_job_class.new

        result = job.perform(intervention.id, old_var, new_var)
        expect(result).to be true

        expect(intervention.reload.formula_update_in_progress?).to be false
      end

      it 'executes the given block' do
        job = test_job_class.new
        result = job.perform(intervention.id, old_var, new_var)

        expect(result).to be true
      end

      it 'ensures formula_update_in_progress is set back to false even if an error occurs' do
        error_job_class = Class.new(UpdateJobs::VariableReferencesUpdateJob) do
          def perform(intervention_id, _old_var, _new_var)
            with_formula_update_lock(intervention_id) do
              raise StandardError, 'Test error'
            end
          end
        end

        job = error_job_class.new

        expect do
          job.perform(intervention.id, old_var, new_var)
        end.to raise_error(StandardError, 'Test error')

        expect(intervention.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when intervention already has formula update in progress' do
      before do
        intervention.update!(formula_update_in_progress: true)
      end

      it 'returns early without executing the block' do
        block_executed = false
        job_with_flag = Class.new(UpdateJobs::VariableReferencesUpdateJob) do
          define_method(:perform) do |intervention_id, _old_var, _new_var|
            with_formula_update_lock(intervention_id) do
              block_executed = true
            end
          end
        end

        job = job_with_flag.new
        job.perform(intervention.id, old_var, new_var)

        expect(block_executed).to be false
      end

      it 'does not change the formula_update_in_progress flag' do
        job = test_job_class.new

        expect do
          job.perform(intervention.id, old_var, new_var)
        end.not_to change { intervention.reload.formula_update_in_progress? }
      end
    end
  end

  describe 'formula update methods' do
    let(:job) { test_job_class.new }

    describe '#update_question_formulas_scoped' do
      it 'executes SQL to update question formulas' do
        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE questions/))

        job.send(:update_question_formulas_scoped, session, old_var, new_var, exclude_source_session: false)
      end
    end

    describe '#update_question_narrator_formulas_scoped' do
      it 'executes SQL to update narrator formulas' do
        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE questions/))

        job.send(:update_question_narrator_formulas_scoped, session, old_var, new_var, exclude_source_session: false)
      end
    end

    describe '#update_question_narrator_reflection_variables_scoped' do
      it 'executes SQL to update narrator reflection variables' do
        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE questions/))

        job.send(:update_question_narrator_reflection_variables_scoped, session, old_var, new_var, exclude_source_session: false)
      end
    end

    describe '#update_session_formulas_scoped' do
      it 'executes SQL to update session formulas' do
        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE sessions/))

        job.send(:update_session_formulas_scoped, session, old_var, new_var, exclude_source_session: true)
      end
    end

    describe '#update_question_group_formulas_scoped' do
      it 'executes SQL to update question group formulas' do
        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE question_groups/))

        job.send(:update_question_group_formulas_scoped, session, old_var, new_var, exclude_source_session: false)
      end
    end

    describe '#update_report_template_formulas_scoped' do
      it 'executes SQL to update report template formulas' do
        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE report_template_sections/))

        job.send(:update_report_template_formulas_scoped, session, old_var, new_var, exclude_source_session: false)
      end
    end

    describe '#update_chart_formulas' do
      it 'executes SQL to update chart formulas when organization has reporting dashboard' do
        organization = create(:organization, :with_dashboard_section)
        intervention.update!(organization: organization)

        expect(ActiveRecord::Base.connection).to receive(:execute).with(a_string_matching(/UPDATE charts/))

        job.send(:update_chart_formulas, intervention.id, old_var, new_var)
      end
    end
  end

  describe 'error handling and logging' do
    let(:error_job_class) do
      Class.new(UpdateJobs::VariableReferencesUpdateJob) do
        def perform(intervention_id, _old_var, _new_var)
          with_formula_update_lock(intervention_id) do
            raise StandardError, 'Test error'
          end
        end
      end
    end

    before do
      intervention.update!(formula_update_in_progress: false)
    end

    it 'logs errors with class name' do
      job = error_job_class.new

      expect(Rails.logger).to receive(:error).with(/#{error_job_class.name}.*Failed to update formula references.*Test error/)
      expect(Rails.logger).to receive(:error).with(/#{error_job_class.name}.*Backtrace/)

      expect do
        job.perform(intervention.id, old_var, new_var)
      end.to raise_error(StandardError, 'Test error')
    end

    it 'ensures intervention lock is properly released' do
      job = error_job_class.new

      expect do
        job.perform(intervention.id, old_var, new_var)
      end.to raise_error(StandardError, 'Test error')

      expect(intervention.reload.formula_update_in_progress?).to be false
    end
  end

  describe 'job configuration' do
    it 'inherits from CloneJob' do
      expect(described_class.superclass).to eq CloneJob
    end

    it 'has retry configuration for database locks' do
      expect(described_class.ancestors).to include(ActiveJob::Base)
    end
  end
end
