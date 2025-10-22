# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::VariableReferences::BaseService, type: :service do
  describe '.call' do
    let(:service_class) do
      Class.new(described_class) do
        def initialize(*)
          super()
        end

        def call
          'service_called'
        end
      end
    end

    it 'instantiates and calls the service' do
      result = service_class.call('arg1', 'arg2')
      expect(result).to eq('service_called')
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new }
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:organization) { create(:organization) }
    let(:intervention) { create(:intervention, user: user, organization: organization) }
    let(:session) { create(:session, intervention: intervention, variable: 'session_var') }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question, question_group: question_group) }

    before do
      # Make private methods accessible for testing
      described_class.send(:public, *described_class.private_instance_methods)
    end

    describe '#update_chart_formulas' do
      let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
      let!(:chart) { create(:chart, dashboard_section: create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard)) }

      it 'updates chart formulas when organization has reporting dashboard' do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_call_original

        service.update_chart_formulas(intervention.id, 'old_var', 'new_var')

        expect(ActiveRecord::Base.connection).to have_received(:execute)
      end

      it 'does nothing when organization has no reporting dashboard' do
        organization.reporting_dashboard.destroy
        organization.reload

        expect(ActiveRecord::Base.connection).not_to receive(:execute)

        service.update_chart_formulas(intervention.id, 'old_var', 'new_var')
      end
    end

    describe '#build_jsonb_formula_update_sql' do
      it 'builds correct SQL for updating formulas' do
        base_query = double
        allow(base_query).to receive_message_chain(:select, :where, :to_sql).and_return('SELECT questions.id FROM questions WHERE questions.id = 1')

        sql = service.build_jsonb_formula_update_sql('questions', 'old_var', 'new_var', base_query)

        expect(sql).to include('UPDATE questions')
        expect(sql).to include('SET formulas =')
        expect(sql).to include('new_var')
        expect(sql).to include('WHERE questions.id IN')
      end
    end

    describe '#build_text_formula_update_sql' do
      it 'builds correct SQL for updating text formulas' do
        base_query = ReportTemplate::Section.where(id: 1)
        sql = service.build_text_formula_update_sql('report_template_sections', 'formula', 'old_var', 'new_var', base_query)

        expect(sql).to include('UPDATE report_template_sections')
        expect(sql).to include('SET formula =')
        expect(sql).to include('new_var')
      end
    end

    describe '#build_question_base_query' do
      it 'builds query for same session when exclude_source_session is false' do
        query = service.build_question_base_query(session, false)
        expected_query = Question.joins(:question_group).where(question_groups: { session_id: session.id })
        expect(query.to_sql).to eq(expected_query.to_sql)
      end

      it 'builds query excluding source session when exclude_source_session is true' do
        query = service.build_question_base_query(session, true)
        expected_query = Question.joins(question_group: { session: :intervention })
                                 .where(interventions: { id: session.intervention_id })
                                 .where.not(question_groups: { session_id: session.id })
        expect(query.to_sql).to eq(expected_query.to_sql)
      end
    end

    describe '#sanitize_like_pattern' do
      it 'escapes special characters' do
        expect(service.sanitize_like_pattern('var%_\\')).to eq('var\\%\\_\\\\')
      end
    end
  end
end
