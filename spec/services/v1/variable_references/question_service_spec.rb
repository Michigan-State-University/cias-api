# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::VariableReferences::QuestionService, type: :service do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:organization) { create(:organization) }
  let(:intervention) { create(:intervention, user: user, organization: organization) }
  let(:session) { create(:session, intervention: intervention, variable: 'session_var') }
  let(:question_group) { create(:question_group, session: session) }
  let(:question_id) { 1 }
  let(:question) { instance_double(Question, id: question_id, session: session) }

  before do
    allow(Question).to receive(:find).with(question_id).and_return(question)
  end

  describe '#initialize' do
    it 'sets instance variables' do
      service = described_class.new(question_id, 'old_var', 'new_var')

      expect(service.instance_variable_get(:@question_id)).to eq(question_id)
      expect(service.instance_variable_get(:@old_variable_name)).to eq('old_var')
      expect(service.instance_variable_get(:@new_variable_name)).to eq('new_var')
    end
  end

  describe '#call' do
    let(:service) { described_class.new(question_id, 'old_var', 'new_var') }

    context 'when variable names are the same' do
      it 'returns early without making changes' do
        service = described_class.new(question_id, 'same_var', 'same_var')

        expect(ActiveRecord::Base).not_to receive(:transaction)

        service.call
      end
    end

    context 'when old variable name is blank' do
      it 'returns early without making changes' do
        service = described_class.new(question_id, '', 'new_var')

        expect(ActiveRecord::Base).not_to receive(:transaction)

        service.call
      end
    end

    context 'when new variable name is blank' do
      it 'returns early without making changes' do
        service = described_class.new(question_id, 'old_var', '')

        expect(ActiveRecord::Base).not_to receive(:transaction)

        service.call
      end
    end

    context 'when variable names are different and not blank' do
      it 'executes the update in a transaction' do
        expect(ActiveRecord::Base).to receive(:transaction).and_yield

        allow(service).to receive(:update_direct_variable_references)
        allow(service).to receive(:update_cross_session_variable_references)

        expect(Rails.logger).to receive(:info).with(/Service completed successfully/)

        service.call
      end

      it 'calls update methods with correct parameters' do
        allow(ActiveRecord::Base).to receive(:transaction).and_yield

        expect(service).to receive(:update_direct_variable_references)
        expect(service).to receive(:update_cross_session_variable_references)

        service.call
      end
    end
  end

  describe 'private methods' do
    let(:service) { described_class.new(question_id, 'old_var', 'new_var') }

    before do
      described_class.send(:public, *described_class.private_instance_methods)
    end

    describe '#question' do
      it 'returns the question' do
        expect(service.question).to eq(question)
      end

      it 'memoizes the question' do
        expect(Question).to receive(:find).once.and_return(question)

        2.times { service.question }
      end
    end

    describe '#source_session' do
      it 'returns the session from the question' do
        expect(service.source_session).to eq(session)
      end
    end

    describe '#old_cross_session_pattern' do
      it 'returns the pattern with session variable' do
        expect(service.old_cross_session_pattern).to eq('session_var.old_var')
      end
    end

    describe '#new_cross_session_pattern' do
      it 'returns the new pattern with session variable' do
        expect(service.new_cross_session_pattern).to eq('session_var.new_var')
      end
    end

    describe '#update_direct_variable_references' do
      it 'calls all update methods for direct references' do
        expect(service).to receive(:update_question_formulas_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)
        expect(service).to receive(:update_question_narrator_formulas_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)
        expect(service).to receive(:update_question_narrator_reflection_variables_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)
        expect(service).to receive(:update_question_group_formulas_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)
        expect(service).to receive(:update_session_formulas_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)
        expect(service).to receive(:update_report_template_formulas_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)
        expect(service).to receive(:update_sms_plan_formulas_scoped).with(session, 'old_var', 'new_var', exclude_source_session: false)

        service.update_direct_variable_references
      end
    end

    describe '#update_cross_session_variable_references' do
      it 'calls all update methods for cross-session references' do
        expect(service).to receive(:update_question_formulas_scoped).with(session, 'session_var.old_var', 'session_var.new_var', exclude_source_session: true)
        expect(service).to receive(:update_question_narrator_formulas_scoped).with(session, 'session_var.old_var', 'session_var.new_var',
                                                                                   exclude_source_session: true)
        expect(service).to receive(:update_question_narrator_reflection_variables_scoped).with(session, 'session_var.old_var', 'session_var.new_var',
                                                                                               exclude_source_session: true)
        expect(service).to receive(:update_question_group_formulas_scoped).with(session, 'session_var.old_var', 'session_var.new_var',
                                                                                exclude_source_session: true)
        expect(service).to receive(:update_session_formulas_scoped).with(session, 'session_var.old_var', 'session_var.new_var', exclude_source_session: true)
        expect(service).to receive(:update_report_template_formulas_scoped).with(session, 'session_var.old_var', 'session_var.new_var',
                                                                                 exclude_source_session: true)
        expect(service).to receive(:update_sms_plan_formulas_scoped).with(session, 'session_var.old_var', 'session_var.new_var',
                                                                          exclude_source_session: true)
        expect(service).to receive(:update_chart_formulas).with(session.intervention_id, 'session_var.old_var', 'session_var.new_var')

        service.update_cross_session_variable_references
      end
    end
  end
end
