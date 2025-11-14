# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::VariableReferences::AnswerOptionsService, type: :service do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  describe '#initialize' do
    it 'sets instance variables for changes only' do
      changed_values = [{ 'variable' => 'var1', 'old_payload' => '<p>old</p>', 'new_payload' => '<p>new</p>', 'value' => '1' }]
      service = described_class.new('q1', changed_values)

      expect(service.question_id).to eq('q1')
      expect(service.changed_answer_values).to eq(changed_values)
      expect(service.new_answer_options).to eq([])
      expect(service.deleted_answer_options).to eq([])
    end

    it 'sets instance variables for all parameters' do
      changed = [{ 'old_payload' => '<p>old</p>', 'new_payload' => '<p>new</p>' }]
      new_options = [{ 'payload' => '<p>new option</p>', 'value' => '2' }]
      deleted = [{ 'payload' => '<p>deleted</p>', 'value' => '3' }]
      grid_columns = { changed: { '1' => { 'old' => '<p>col1</p>', 'new' => '<p>col1 updated</p>' } }, new: {}, deleted: {} }

      service = described_class.new('q1', changed, new_options, deleted, grid_columns)

      expect(service.changed_answer_values).to eq(changed)
      expect(service.new_answer_options).to eq(new_options)
      expect(service.deleted_answer_options).to eq(deleted)
      expect(service.instance_variable_get(:@changed_columns)).to eq(grid_columns[:changed])
    end

    it 'handles nil parameters gracefully' do
      service = described_class.new('q1', nil, nil, nil, {})

      expect(service.changed_answer_values).to eq([])
      expect(service.new_answer_options).to eq([])
      expect(service.deleted_answer_options).to eq([])
    end
  end

  describe '#call' do
    context 'when all parameters are blank' do
      it 'returns early without making changes' do
        service = described_class.new('q1', [], [], [], {})

        expect(ActiveRecord::Base).not_to receive(:transaction)
        service.call
      end
    end

    context 'when changed_answer_values is present' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:changed_values) do
        [{ 'variable' => 'var1', 'old_payload' => '<p>old</p>', 'new_payload' => '<p>new</p>', 'value' => '1' }]
      end

      it 'executes update in a transaction' do
        service = described_class.new(question.id, changed_values)

        expect(ActiveRecord::Base).to receive(:transaction).and_yield
        expect(service).to receive(:update_reflections_for_changed_answers)

        service.call
      end
    end

    context 'when new_answer_options is present' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:new_options) { [{ 'payload' => '<p>new</p>', 'value' => '2', 'variable' => 'var2' }] }

      it 'adds new reflections' do
        service = described_class.new(question.id, [], new_options)

        expect(service).to receive(:add_new_reflections_for_new_answers)

        service.call
      end
    end

    context 'when deleted_answer_options is present' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:deleted) { [{ 'payload' => '<p>old</p>', 'value' => '1' }] }

      it 'deletes reflections' do
        service = described_class.new(question.id, [], [], deleted)

        expect(service).to receive(:delete_reflections_for_deleted_answers)

        service.call
      end
    end

    context 'when grid column changes are present' do
      let(:question) { create(:question_grid, question_group: question_group) }
      let(:grid_columns) do
        {
          changed: { '1' => { 'old' => '<p>col</p>', 'new' => '<p>col updated</p>' } },
          new: { '2' => '<p>new col</p>' },
          deleted: { '3' => '<p>deleted col</p>' }
        }
      end

      it 'handles all grid column operations' do
        service = described_class.new(question.id, [], [], [], grid_columns)

        expect(service).to receive(:update_reflections_for_changed_columns)
        expect(service).to receive(:add_new_reflections_for_new_columns)
        expect(service).to receive(:delete_reflections_for_deleted_columns)

        service.call
      end
    end

    context 'when an error occurs' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:changed_values) { [{ 'old_payload' => '<p>old</p>', 'new_payload' => '<p>new</p>' }] }

      it 'logs the error and re-raises' do
        service = described_class.new(question.id, changed_values)
        error = StandardError.new('Database error')

        allow(service).to receive(:update_reflections_for_changed_answers).and_raise(error)
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { service.call }.to raise_error(StandardError, 'Database error')
      end
    end
  end

  describe 'private methods' do
    before do
      described_class.send(:public, *described_class.private_instance_methods)
    end

    describe '#normalize_payload' do
      let(:service) { described_class.new('q1', []) }

      it 'strips surrounding <p> tags' do
        expect(service.normalize_payload('<p>test</p>')).to eq('test')
      end

      it 'strips surrounding whitespace' do
        expect(service.normalize_payload('  test  ')).to eq('test')
      end

      it 'handles both p tags and whitespace' do
        expect(service.normalize_payload('  <p> test </p>  ')).to eq('test')
      end

      it 'converts <br> to empty string' do
        expect(service.normalize_payload('<br>')).to eq('')
        expect(service.normalize_payload('<br/>')).to eq('')
        expect(service.normalize_payload('<br />')).to eq('')
      end

      it 'returns non-string payloads as-is' do
        expect(service.normalize_payload(nil)).to be_nil
        expect(service.normalize_payload(123)).to eq(123)
      end
    end

    describe '#normalize_answer_changes' do
      let(:service) { described_class.new('q1', []) }

      it 'normalizes payloads in changes' do
        changes = [
          { 'variable' => 'var1', 'old_payload' => '<p>old</p>', 'new_payload' => '<p>new</p>', 'value' => '1' }
        ]

        result = service.normalize_answer_changes(changes)

        expect(result[0]['old_payload']).to eq('old')
        expect(result[0]['new_payload']).to eq('new')
        expect(result[0]['variable']).to eq('var1')
        expect(result[0]['value']).to eq('1')
      end

      it 'handles blank changes' do
        expect(service.normalize_answer_changes(nil)).to eq([])
        expect(service.normalize_answer_changes([])).to eq([])
      end

      it 'compacts nil values' do
        changes = [
          { 'variable' => nil, 'old_payload' => '<p>old</p>', 'new_payload' => '<p>new</p>', 'value' => '1', 'new_value' => nil }
        ]

        result = service.normalize_answer_changes(changes)

        expect(result[0].key?('variable')).to be false
        expect(result[0].key?('new_value')).to be false
      end
    end

    describe '#build_new_reflection_objects' do
      context 'for Single/Multiple questions' do
        let(:question) { create(:question_single, question_group: question_group) }
        let(:new_options) do
          [
            { 'payload' => '<p>Option 1</p>', 'value' => '1', 'variable' => 'var1' },
            { 'payload' => '<p>Option 2</p>', 'value' => '2', 'variable' => 'var2' }
          ]
        end
        let(:service) { described_class.new(question.id, [], new_options) }

        it 'builds reflection objects with normalized payloads' do
          result = service.build_new_reflection_objects

          expect(result.size).to eq(2)
          expect(result[0][:payload]).to eq('Option 1')
          expect(result[0][:value]).to eq('1')
          expect(result[0][:variable]).to eq('var1')
          expect(result[0][:text]).to eq([])
          expect(result[0][:sha256]).to eq([])
        end
      end

      context 'for Grid questions' do
        let(:question) do
          create(:question_grid, question_group: question_group,
                                 body: {
                                   'data' => [
                                     {
                                       'payload' => {
                                         'rows' => [
                                           { 'payload' => '<p>Row 1</p>', 'variable' => { 'name' => 'row1' } },
                                           { 'payload' => '<p>Row 2</p>', 'variable' => { 'name' => 'row2' } }
                                         ],
                                         'columns' => [
                                           { 'payload' => '<p>Col A</p>', 'variable' => { 'value' => 'a' } },
                                           { 'payload' => '<p>Col B</p>', 'variable' => { 'value' => 'b' } }
                                         ]
                                       }
                                     }
                                   ]
                                 })
        end
        let(:new_rows) { [{ 'payload' => '<p>Row 3</p>', 'variable' => 'row3' }] }
        let(:service) { described_class.new(question.id, [], new_rows) }

        it 'builds reflection objects for each row × column combination' do
          result = service.build_new_reflection_objects

          expect(result.size).to eq(2) # 1 new row × 2 columns
          expect(result[0][:payload]).to eq('Row 3 - Col A')
          expect(result[0][:value]).to eq('a')
          expect(result[0][:variable]).to be_nil
          expect(result[1][:payload]).to eq('Row 3 - Col B')
          expect(result[1][:value]).to eq('b')
        end
      end
    end

    describe '#build_deletion_filter_conditions' do
      let(:service) { described_class.new('q1', []) }

      it 'builds conditions for deletions without variables' do
        deletions = [{ 'payload' => '<p>Option 1</p>' }]
        service.instance_variable_set(:@deleted_answer_options, deletions)

        result = service.build_deletion_filter_conditions

        expect(result).to include("reflection_item->>'payload' = 'Option 1'")
        expect(result).to include("reflection_item->>'payload' LIKE 'Option 1 - %'")
      end

      it 'builds conditions for deletions with variables' do
        deletions = [{ 'payload' => '<p>Option 1</p>', 'variable' => 'var1' }]
        service.instance_variable_set(:@deleted_answer_options, deletions)

        result = service.build_deletion_filter_conditions

        expect(result).to include("reflection_item->>'variable' = 'var1'")
        expect(result).to include("reflection_item->>'payload' = 'Option 1'")
        expect(result).to include("reflection_item->>'variable' IS NULL")
      end

      it 'combines multiple deletions with OR' do
        deletions = [
          { 'payload' => '<p>Option 1</p>' },
          { 'payload' => '<p>Option 2</p>' }
        ]
        service.instance_variable_set(:@deleted_answer_options, deletions)

        result = service.build_deletion_filter_conditions

        expect(result.scan(' OR ').count).to be >= 1
      end
    end

    describe '#build_payload_update_cases' do
      context 'for Single questions' do
        let(:question) { create(:question_single, question_group: question_group) }
        let(:service) { described_class.new(question.id, []) }

        it 'delegates to build_single_question_update_cases for value-based matching' do
          changes = [
            { 'variable' => 'var1', 'old_payload' => 'Old', 'new_payload' => 'New', 'value' => '1' }
          ]

          result = service.build_payload_update_cases(changes)

          expect(result).to include("reflection_item->>'value' = '1'")
        end

        it 'updates both value and payload when value changes' do
          changes = [
            { 'variable' => 'var1', 'old_payload' => 'Old', 'new_payload' => 'New', 'value' => '1', 'new_value' => '2' }
          ]

          result = service.build_payload_update_cases(changes)

          expect(result).to include("'{value}'")
          expect(result).to include("'{payload}'")
        end
      end

      context 'for Multiple questions' do
        let(:question) { create(:question_multiple, question_group: question_group) }
        let(:service) { described_class.new(question.id, []) }

        it 'delegates to build_variable_based_question_update_cases for variable-based matching' do
          changes = [
            { 'variable' => 'var1', 'old_payload' => 'Old', 'new_payload' => 'New', 'value' => '1' }
          ]

          result = service.build_payload_update_cases(changes)

          expect(result).to include("reflection_item->>'payload' = 'Old'")
        end

        it 'handles grid payloads with separator' do
          changes = [
            { 'variable' => nil, 'old_payload' => 'Row 1', 'new_payload' => 'Row 1 Updated', 'value' => '1' }
          ]

          result = service.build_payload_update_cases(changes)

          expect(result).to include("reflection_item->>'payload' LIKE 'Row 1 - %'")
        end
      end
    end

    describe '#normalize_column_changes' do
      let(:service) { described_class.new('q1', []) }

      it 'normalizes column change payloads' do
        changes = {
          '1' => { 'old' => '<p>Col 1</p>', 'new' => '<p>Col 1 Updated</p>' },
          '2' => { 'old' => '<p>Col 2</p>', 'new' => '<p>Col 2 Updated</p>' }
        }

        result = service.normalize_column_changes(changes)

        expect(result['1']['old']).to eq('Col 1')
        expect(result['1']['new']).to eq('Col 1 Updated')
        expect(result['2']['old']).to eq('Col 2')
        expect(result['2']['new']).to eq('Col 2 Updated')
      end
    end

    describe '#build_column_update_cases' do
      let(:service) { described_class.new('q1', []) }

      it 'builds CASE statements for column updates' do
        normalized_changes = {
          '1' => { 'old' => 'Col 1', 'new' => 'Col 1 Updated' }
        }

        result = service.build_column_update_cases(normalized_changes)

        expect(result).to include("reflection_item->>'value' = '1'")
        expect(result).to include("reflection_item->>'payload' LIKE '% - ' || 'Col 1'")
        expect(result).to include("'Col 1 Updated'")
      end

      it 'handles multiple column changes' do
        normalized_changes = {
          '1' => { 'old' => 'Col 1', 'new' => 'Col 1 Updated' },
          '2' => { 'old' => 'Col 2', 'new' => 'Col 2 Updated' }
        }

        result = service.build_column_update_cases(normalized_changes)

        expect(result).to include("reflection_item->>'value' = '1'")
        expect(result).to include("reflection_item->>'value' = '2'")
      end
    end
  end
end
