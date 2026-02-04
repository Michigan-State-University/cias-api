# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::VariableReferences::SessionService, type: :service do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:organization) { create(:organization) }
  let(:intervention) { create(:intervention, user: user, organization: organization) }
  let(:session) { create(:session, intervention: intervention, variable: 'old_session_var') }

  before do
    allow(Session).to receive(:find).with(session.id).and_return(session)
  end

  describe '#initialize' do
    it 'sets instance variables' do
      service = described_class.new(session.id, 'old_var', 'new_var')

      expect(service.instance_variable_get(:@session_id)).to eq(session.id)
      expect(service.instance_variable_get(:@old_session_variable)).to eq('old_var')
      expect(service.instance_variable_get(:@new_session_variable)).to eq('new_var')
    end
  end

  describe '#call' do
    let(:service) { described_class.new(session.id, 'old_session_var', 'new_session_var') }

    context 'when session variables are the same' do
      it 'returns early without making changes' do
        service = described_class.new(session.id, 'same_var', 'same_var')

        expect(ActiveRecord::Base).not_to receive(:transaction)

        service.call
      end
    end

    context 'when old session variable is blank' do
      it 'returns early without making changes' do
        service = described_class.new(session.id, '', 'new_var')

        expect(ActiveRecord::Base).not_to receive(:transaction)

        service.call
      end
    end

    context 'when new session variable is blank' do
      it 'returns early without making changes' do
        service = described_class.new(session.id, 'old_var', '')

        expect(ActiveRecord::Base).not_to receive(:transaction)

        service.call
      end
    end

    context 'when session variables are different and not blank' do
      let!(:question1) { create(:question_single, question_group: create(:question_group, session: session)) }
      let!(:question2) { create(:question_multiple, question_group: create(:question_group, session: session)) }

      it 'executes the update in a transaction' do
        expect(ActiveRecord::Base).to receive(:transaction).and_yield

        allow(service).to receive_messages(patterns_to_update: ['old_session_var', 'old_session_var.var1'],
                                           new_patterns: ['new_session_var', 'new_session_var.var1'])
        allow(service).to receive(:update_variable_references)

        expect(Rails.logger).to receive(:info).with(/Service completed successfully/)

        service.call
      end

      it 'calls update_variable_references for each pattern pair' do
        allow(ActiveRecord::Base).to receive(:transaction).and_yield

        allow(service).to receive_messages(patterns_to_update: %w[pattern1 pattern2], new_patterns: %w[new_pattern1 new_pattern2])

        expect(service).to receive(:update_variable_references).with('pattern1', 'new_pattern1')
        expect(service).to receive(:update_variable_references).with('pattern2', 'new_pattern2')

        service.call
      end
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new(session.id, 'old_session_var', 'new_session_var') }

    before do
      described_class.send(:public, *described_class.private_instance_methods)
    end

    describe '#session' do
      it 'returns the session' do
        expect(service.session).to eq(session)
      end

      it 'memoizes the session' do
        expect(Session).to receive(:find).once.and_return(session)

        2.times { service.session }
      end
    end

    describe '#question_variables' do
      context 'with single questions' do
        let!(:question) { create(:question_single, question_group: create(:question_group, session: session)) }

        it 'extracts variables from single questions' do
          expect(service.question_variables).to include('single_var')
        end
      end

      context 'with multiple questions' do
        let!(:question) { create(:question_multiple, question_group: create(:question_group, session: session)) }

        it 'extracts variables from multiple questions' do
          expect(service.question_variables).to include('answer_1')
        end
      end

      context 'with grid questions' do
        let!(:question) { create(:question_grid, question_group: create(:question_group, session: session)) }

        it 'extracts variables from grid questions' do
          expect(service.question_variables).to include('row1')
        end
      end

      it 'memoizes the result' do
        expect(service).to receive(:extract_question_variables_from_session).once.and_return([])

        2.times { service.question_variables }
      end
    end

    describe '#patterns_to_update' do
      it 'includes the session variable and combined patterns' do
        allow(service).to receive(:question_variables).and_return(%w[var1 var2])

        expected = ['old_session_var', 'old_session_var.var1', 'old_session_var.var2']
        expect(service.patterns_to_update).to eq(expected)
      end

      it 'memoizes the result' do
        allow(service).to receive(:question_variables).and_return([])

        expect(service).to receive(:question_variables).once

        2.times { service.patterns_to_update }
      end
    end

    describe '#new_patterns' do
      it 'includes the new session variable and combined patterns' do
        allow(service).to receive(:question_variables).and_return(%w[var1 var2])

        expected = ['new_session_var', 'new_session_var.var1', 'new_session_var.var2']
        expect(service.new_patterns).to eq(expected)
      end

      it 'memoizes the result' do
        allow(service).to receive(:question_variables).and_return([])

        expect(service).to receive(:question_variables).once

        2.times { service.new_patterns }
      end
    end

    describe '#extract_question_variables_from_session' do
      it 'executes the correct SQL query' do
        allow(ActiveRecord::Base.connection).to receive(:exec_query).with(
          a_string_matching(/WITH session_questions AS/),
          'SQL',
          [session.id]
        ).and_return(double(rows: [['var1'], ['var2']]))

        result = service.extract_question_variables_from_session(session)
        expect(result).to eq(%w[var1 var2])
      end

      it 'filters out empty and nil values' do
        allow(ActiveRecord::Base.connection).to receive(:exec_query).and_return(double(rows: [['var1'], ['var2']]))

        result = service.extract_question_variables_from_session(session)
        expect(result).to eq(%w[var1 var2])
      end
    end

    describe '#update_variable_references' do
      it 'calls all update methods' do
        expect(service).to receive(:update_question_formulas_scoped).with(session, 'old_pattern', 'new_pattern', exclude_source_session: true)
        expect(service).to receive(:update_question_narrator_formulas_scoped).with(session, 'old_pattern', 'new_pattern', exclude_source_session: true)
        expect(service).to receive(:update_question_group_formulas_scoped).with(session, 'old_pattern', 'new_pattern', exclude_source_session: true)
        expect(service).to receive(:update_session_formulas_scoped).with(session, 'old_pattern', 'new_pattern', exclude_source_session: true)
        expect(service).to receive(:update_report_template_formulas_scoped).with(session, 'old_pattern', 'new_pattern', exclude_source_session: true)
        expect(service).to receive(:update_sms_plan_formulas_scoped).with(session, 'old_pattern', 'new_pattern', exclude_source_session: true)
        expect(service).to receive(:update_chart_formulas).with(session.intervention_id, 'old_pattern', 'new_pattern')
        expect(service).to receive(:update_days_after_date_session_variable_references).with('old_session_var', 'new_session_var')

        service.update_variable_references('old_pattern', 'new_pattern')
      end
    end
  end
end
