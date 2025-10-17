# frozen_string_literal: true

RSpec.describe V1::VariableReferencesUpdate, type: :service do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  let(:old_var) { 'old_variable' }
  let(:new_var) { 'new_variable' }

  describe '.call' do
    context 'when intervention does not have formula update in progress' do
      before do
        intervention.update!(formula_update_in_progress: false)
      end

      it 'sets formula_update_in_progress to true during execution' do
        described_class.call(intervention.id) do |service|
          expect(intervention.reload.formula_update_in_progress?).to be true
        end

        expect(intervention.reload.formula_update_in_progress?).to be false
      end

      it 'executes the given block' do
        result = nil
        described_class.call(intervention.id) do |service|
          result = true
        end

        expect(result).to be true
      end

      it 'ensures formula_update_in_progress is set back to false even if an error occurs' do
        expect do
          described_class.call(intervention.id) do |_service|
            raise StandardError, 'Test error'
          end
        end.to raise_error(StandardError, 'Test error')

        expect(intervention.reload.formula_update_in_progress?).to be false
      end
    end

    context 'when intervention already has formula update in progress' do
      before do
        intervention.update!(formula_update_in_progress: true)
      end

      it 'does not change the formula_update_in_progress flag' do
        described_class.call(intervention.id) do |_service|
          # This block should not execute
          expect(true).to be false
        end

        expect(intervention.reload.formula_update_in_progress?).to be true
      end

      it 'returns early without executing the block' do
        block_executed = false

        described_class.call(intervention.id) do |_service|
          block_executed = true
        end

        expect(block_executed).to be false
      end
    end
  end

  describe 'formula update methods' do
    let(:chart) { create(:chart, dashboard_section: dashboard_section) }
    let(:dashboard_section) { create(:dashboard_section) }
    let(:organization) { create(:organization, reporting_dashboard: reporting_dashboard) }
    let(:reporting_dashboard) { create(:reporting_dashboard) }
    let(:question) { create(:question_single, question_group: question_group) }
    let(:question_group_with_formulas) { create(:question_group, session: session, formulas: [{ payload: 'old_variable + 1', patterns: [] }]) }
    let(:session_with_formulas) { create(:session, intervention: intervention, formulas: [{ payload: 'old_variable + 1', patterns: [] }]) }
    let(:report_template_section) { create(:report_template_section, report_template: report_template, formula: 'old_variable + 1') }
    let(:report_template) { create(:report_template, session: session) }

    before do
      intervention.update!(organization: organization)
      chart.update!(formula: { payload: 'old_variable + 1', patterns: [] })
    end

    it '#update_question_formulas_scoped executes SQL to update question formulas' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_question_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
      end
    end

    it '#update_question_narrator_formulas_scoped executes SQL to update narrator formulas' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_question_narrator_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
      end
    end

    it '#update_question_narrator_reflection_variables_scoped executes SQL to update narrator reflection variables' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_question_narrator_reflection_variables_scoped(session, old_var, new_var, exclude_source_session: false)
      end
    end

    it '#update_session_formulas_scoped executes SQL to update session formulas' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_session_formulas_scoped(session, old_var, new_var, exclude_source_session: true)
      end
    end

    it '#update_question_group_formulas_scoped executes SQL to update question group formulas' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_question_group_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
      end
    end

    it '#update_report_template_formulas_scoped executes SQL to update report template formulas' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_report_template_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
      end
    end

    it '#update_chart_formulas executes SQL to update chart formulas when organization has reporting dashboard' do
      described_class.call(intervention.id) do |service|
        expect(ActiveRecord::Base.connection).to receive(:execute).at_least(:once)
        service.update_chart_formulas(old_var, new_var)
      end
    end
  end

  describe 'error handling and logging' do
    before do
      intervention.update!(formula_update_in_progress: false)
    end

    it 'logs errors with class name' do
      expect(Rails.logger).to receive(:error).with(/V1::VariableReferencesUpdate/).at_least(:once)

      expect do
        described_class.call(intervention.id) do |_service|
          raise StandardError, 'Test error'
        end
      end.to raise_error(StandardError, 'Test error')
    end

    it 'ensures intervention lock is properly released' do
      expect do
        described_class.call(intervention.id) do |_service|
          raise StandardError, 'Test error'
        end
      end.to raise_error(StandardError, 'Test error')

      expect(intervention.reload.formula_update_in_progress?).to be false
    end
  end
end
