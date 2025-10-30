# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::VariableReferences::AnswerOptionsService, type: :service do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_id) { 1 }
  let(:question) { instance_double(Question, id: question_id, session: session) }
  let(:changed_answer_values) { { 'var1' => { 'old_payload' => 'new_payload' } } }
  let(:service) { described_class.new(question_id, changed_answer_values) }

  before do
    allow(Question).to receive(:find).with(question_id).and_return(question)
  end

  describe '#initialize' do
    it 'sets instance variables' do
      expect(service.instance_variable_get(:@question_id)).to eq(question_id)
      expect(service.instance_variable_get(:@changed_answer_values)).to eq(changed_answer_values)
    end
  end

  describe '#call' do
    context 'when changed_answer_values is blank' do
      let(:changed_answer_values) { {} }

      it 'returns early without making changes' do
        expect(ActiveRecord::Base).not_to receive(:transaction)
        service.call
      end
    end

    context 'when changed_answer_values is nil' do
      let(:changed_answer_values) { nil }

      it 'returns early without making changes' do
        expect(ActiveRecord::Base).not_to receive(:transaction)
        service.call
      end
    end

    context 'when changed_answer_values is valid' do
      it 'executes the update in a transaction' do
        expect(ActiveRecord::Base).to receive(:transaction).and_yield
        expect(service).to receive(:update_question_narrator_reflection_answer_options_scoped).with(session, false)
        expect(service).to receive(:update_question_narrator_reflection_answer_options_scoped).with(session, true)

        service.call
      end
    end
  end

  describe 'private methods' do
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

    describe '#normalize_payload' do
      it 'strips surrounding <p> tags' do
        expect(service.normalize_payload('<p>test</p>')).to eq('test')
      end

      it 'strips surrounding whitespace' do
        expect(service.normalize_payload('  test  ')).to eq('test')
      end

      it 'handles both p tags and whitespace' do
        expect(service.normalize_payload('  <p> test </p>  ')).to eq('test')
      end

      it 'returns non-string payloads as-is' do
        expect(service.normalize_payload(nil)).to be_nil
        expect(service.normalize_payload(123)).to eq(123)
      end
    end

    describe '#update_question_narrator_reflection_answer_options_scoped' do
      let(:mock_query) { Question.all }
      let(:mock_sql) { 'UPDATE questions SET ...' }
      let(:mock_connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

      before do
        allow(service).to receive_messages(build_question_base_query: mock_query, build_narrator_reflection_answer_options_update_sql: mock_sql)
        allow(ActiveRecord::Base).to receive(:connection).and_return(mock_connection)
        allow(mock_connection).to receive(:execute)
      end

      it 'calls its dependencies with correct arguments' do
        expect(service).to receive(:build_question_base_query).with(session, false)
        expect(service).to receive(:build_narrator_reflection_answer_options_update_sql).with('questions', mock_query)
        expect(mock_connection).to receive(:execute).with(mock_sql)

        service.update_question_narrator_reflection_answer_options_scoped(session, false)
      end
    end

    describe '#build_narrator_reflection_answer_options_update_sql' do
      let(:mock_base_query) { Question.where(id: 123) }
      let(:changes) { { 'var1' => { '<p>old</p>' => 'new' } } }
      let(:service) { described_class.new(question_id, changes) }

      before do
        subquery = Question.select(:id).where(id: 123)
        allow(mock_base_query).to receive_messages(where: mock_base_query, count: 1, select: subquery)
        allow(subquery).to receive(:reorder).and_return(subquery)
      end

      it 'generates SQL with normalized payloads' do
        sql = service.build_narrator_reflection_answer_options_update_sql('questions', mock_base_query)

        expect(sql).to include("reflection_item->>'payload' = 'old'")
      end

      it 'generates SQL for exact match (Question::Multiple)' do
        sql = service.build_narrator_reflection_answer_options_update_sql('questions', mock_base_query)

        expect(sql).to include("THEN jsonb_set(reflection_item, '{payload}', '\"new\"'::jsonb)")
      end

      it 'generates SQL for LIKE match (Question::Grid)' do
        sql = service.build_narrator_reflection_answer_options_update_sql('questions', mock_base_query)

        expect(sql).to include("reflection_item->>'payload' LIKE 'old - %'")

        expect(sql).to include("THEN jsonb_set(reflection_item, '{payload}', to_jsonb('new' || ' - ' || split_part(reflection_item->>'payload', ' - ', 2)))")
      end
    end
  end
end
