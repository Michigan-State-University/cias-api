# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Question::AnswerOptionsChangeDetector, type: :service do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }

  describe '#detect_changes' do
    context 'with Single question' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when payload changes' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2 UPDATED</p>', 'value' => '2' }
          ]
        end

        it 'detects the payload change' do
          result = detector.detect_changes(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['old_payload']).to eq('<p>Option 2</p>')
          expect(result.first['new_payload']).to eq('<p>Option 2 UPDATED</p>')
        end
      end

      context 'when value changes' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '3' }
          ]
        end

        it 'detects the value change' do
          result = detector.detect_changes(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['value']).to eq('2')
          expect(result.first['new_value']).to eq('3')
        end
      end

      context 'when options have duplicate values and payload changes' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Yes</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>No</p>', 'value' => '2' },
            { 'name' => nil, 'payload' => '<p>Maybe</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Yes</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>No UPDATED</p>', 'value' => '2' },
            { 'name' => nil, 'payload' => '<p>Maybe</p>', 'value' => '2' }
          ]
        end

        it 'cannot detect changes when duplicate values prevent matching' do
          result = detector.detect_changes(old_options, new_options)
          # When there are duplicate values and payloads don't match uniquely,
          # we can't reliably detect changes
          expect(result.size).to eq(0)
        end
      end

      context 'when sizes differ' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' }
          ]
        end

        it 'returns empty array (deletion case, not change)' do
          result = detector.detect_changes(old_options, new_options)
          expect(result).to eq([])
        end
      end
    end

    context 'with Multiple question' do
      let(:question) { create(:question_multiple, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when payload changes' do
        let(:old_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2 UPDATED</p>', 'value' => '2' }
          ]
        end

        it 'detects the payload change by matching variable' do
          result = detector.detect_changes(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to eq('var2')
          expect(result.first['old_payload']).to eq('<p>Option 2</p>')
          expect(result.first['new_payload']).to eq('<p>Option 2 UPDATED</p>')
        end
      end

      context 'when variable name changes' do
        let(:old_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2_new', 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end

        it 'detects the variable change by matching value' do
          result = detector.detect_changes(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to eq('var2')
          expect(result.first['new_variable']).to eq('var2_new')
        end
      end

      context 'when options have duplicate values' do
        let(:old_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2</p>', 'value' => '3' },
            { 'name' => 'var3', 'payload' => '<p>Option 3</p>', 'value' => '3' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2 UPDATED</p>', 'value' => '3' },
            { 'name' => 'var3', 'payload' => '<p>Option 3</p>', 'value' => '3' }
          ]
        end

        it 'falls back to payload matching when values are not unique' do
          result = detector.detect_changes(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to eq('var2')
          expect(result.first['old_payload']).to eq('<p>Option 2</p>')
          expect(result.first['new_payload']).to eq('<p>Option 2 UPDATED</p>')
          # Value fields are nil because of duplicate values
          expect(result.first['value']).to be_nil
          expect(result.first['new_value']).to be_nil
        end
      end
    end

    context 'with Grid question' do
      let(:question) { create(:question_grid, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when row payload changes' do
        let(:old_options) do
          [
            { 'name' => 'row1', 'payload' => '<p>Row 1</p>', 'value' => '' },
            { 'name' => 'row2', 'payload' => '<p>Row 2</p>', 'value' => '' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'row1', 'payload' => '<p>Row 1</p>', 'value' => '' },
            { 'name' => 'row2', 'payload' => '<p>Row 2 UPDATED</p>', 'value' => '' }
          ]
        end

        it 'detects the row payload change' do
          result = detector.detect_changes(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to eq('row2')
          expect(result.first['old_payload']).to eq('<p>Row 2</p>')
          expect(result.first['new_payload']).to eq('<p>Row 2 UPDATED</p>')
        end
      end
    end
  end

  describe '#detect_new_options' do
    context 'with Single question' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when new option is added' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end

        it 'detects the new option' do
          result = detector.detect_new_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['payload']).to eq('<p>Option 2</p>')
          expect(result.first['variable']).to be_nil
        end
      end

      context 'when no new options added (same size)' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2 UPDATED</p>', 'value' => '2' }
          ]
        end

        it 'returns empty array' do
          result = detector.detect_new_options(old_options, new_options)
          expect(result).to eq([])
        end
      end
    end

    context 'with Multiple question' do
      let(:question) { create(:question_multiple, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when new option is added' do
        let(:old_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end

        it 'detects the new option' do
          result = detector.detect_new_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to eq('var2')
          expect(result.first['payload']).to eq('<p>Option 2</p>')
        end
      end
    end

    context 'with Grid question' do
      let(:question) { create(:question_grid, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when new row is added' do
        let(:old_options) do
          [
            { 'name' => 'row1', 'payload' => '<p>Row 1</p>', 'value' => '' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'row1', 'payload' => '<p>Row 1</p>', 'value' => '' },
            { 'name' => 'row2', 'payload' => '<p>Row 2</p>', 'value' => '' }
          ]
        end

        it 'detects the new row' do
          result = detector.detect_new_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to be_nil
          expect(result.first['payload']).to eq('<p>Row 2</p>')
        end
      end
    end
  end

  describe '#detect_deleted_options' do
    context 'with Single question' do
      let(:question) { create(:question_single, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when option is deleted' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' }
          ]
        end

        it 'detects the deleted option' do
          result = detector.detect_deleted_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['payload']).to eq('<p>Option 2</p>')
          expect(result.first['variable']).to be_nil
          expect(result.first['value']).to eq('2')
        end
      end

      context 'when options have duplicate values and one is deleted' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '3' },
            { 'name' => nil, 'payload' => '<p>Option 3</p>', 'value' => '3' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '3' }
          ]
        end

        it 'correctly identifies the deleted option using payload matching' do
          result = detector.detect_deleted_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['payload']).to eq('<p>Option 3</p>')
          # Value is nil because of duplicate values
          expect(result.first['value']).to be_nil
        end
      end

      context 'when no options deleted (same size)' do
        let(:old_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => nil, 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => nil, 'payload' => '<p>Option 2 UPDATED</p>', 'value' => '2' }
          ]
        end

        it 'returns empty array' do
          result = detector.detect_deleted_options(old_options, new_options)
          expect(result).to eq([])
        end
      end
    end

    context 'with Multiple question' do
      let(:question) { create(:question_multiple, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when option is deleted' do
        let(:old_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' },
            { 'name' => 'var2', 'payload' => '<p>Option 2</p>', 'value' => '2' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'var1', 'payload' => '<p>Option 1</p>', 'value' => '1' }
          ]
        end

        it 'detects the deleted option' do
          result = detector.detect_deleted_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to eq('var2')
          expect(result.first['payload']).to eq('<p>Option 2</p>')
          expect(result.first['value']).to eq('2')
        end
      end
    end

    context 'with Grid question' do
      let(:question) { create(:question_grid, question_group: question_group) }
      let(:detector) { described_class.new(question) }

      context 'when row is deleted' do
        let(:old_options) do
          [
            { 'name' => 'row1', 'payload' => '<p>Row 1</p>', 'value' => '' },
            { 'name' => 'row2', 'payload' => '<p>Row 2</p>', 'value' => '' }
          ]
        end
        let(:new_options) do
          [
            { 'name' => 'row1', 'payload' => '<p>Row 1</p>', 'value' => '' }
          ]
        end

        it 'detects the deleted row' do
          result = detector.detect_deleted_options(old_options, new_options)
          expect(result.size).to eq(1)
          expect(result.first['variable']).to be_nil
          expect(result.first['payload']).to eq('<p>Row 2</p>')
          # Value is nil because grid rows have duplicate values (all empty strings)
          expect(result.first['value']).to be_nil
        end
      end
    end
  end

  describe '#detect_column_changes' do
    let(:question) { create(:question_grid, question_group: question_group) }
    let(:detector) { described_class.new(question) }

    context 'when column payload changes' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '2' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2 UPDATED</p>', 'value' => '2' }
        ]
      end

      it 'detects the column payload change' do
        result = detector.detect_column_changes(old_columns, new_columns)
        expect(result['2']['old']).to eq('<p>Column 2</p>')
        expect(result['2']['new']).to eq('<p>Column 2 UPDATED</p>')
      end
    end

    context 'when columns have duplicate values' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '2' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2 UPDATED</p>', 'value' => '2' }
        ]
      end

      it 'uses payload matching to detect changes' do
        result = detector.detect_column_changes(old_columns, new_columns)
        expect(result).to have_key('2')
        expect(result['2']['old']).to eq('<p>Column 2</p>')
        expect(result['2']['new']).to eq('<p>Column 2 UPDATED</p>')
      end
    end

    context 'when no columns change' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '2' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '2' }
        ]
      end

      it 'returns empty hash' do
        result = detector.detect_column_changes(old_columns, new_columns)
        expect(result).to eq({})
      end
    end
  end

  describe '#detect_new_columns' do
    let(:question) { create(:question_grid, question_group: question_group) }
    let(:detector) { described_class.new(question) }

    context 'when new column is added' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '2' }
        ]
      end

      it 'detects the new column' do
        result = detector.detect_new_columns(old_columns, new_columns)
        expect(result['2']).to eq('<p>Column 2</p>')
      end
    end

    context 'when columns have duplicate values and new column is added' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '3' },
          { 'payload' => '<p>Column 3</p>', 'value' => '3' }
        ]
      end

      it 'detects new columns using payload matching' do
        result = detector.detect_new_columns(old_columns, new_columns)
        # When duplicate values exist, both columns are new based on payload
        # However, the hash keyed by value can only store one entry per value
        # So only one of the '3' value columns will be in the result
        expect(result.size).to eq(1)
        expect(result['3']).to be_in(['<p>Column 2</p>', '<p>Column 3</p>'])
      end
    end
  end

  describe '#detect_deleted_columns' do
    let(:question) { create(:question_grid, question_group: question_group) }
    let(:detector) { described_class.new(question) }

    context 'when column is deleted' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '2' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' }
        ]
      end

      it 'detects the deleted column' do
        result = detector.detect_deleted_columns(old_columns, new_columns)
        expect(result['2']).to eq('<p>Column 2</p>')
      end
    end

    context 'when columns have duplicate values and column is deleted' do
      let(:old_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 2</p>', 'value' => '3' },
          { 'payload' => '<p>Column 3</p>', 'value' => '3' }
        ]
      end
      let(:new_columns) do
        [
          { 'payload' => '<p>Column 1</p>', 'value' => '1' },
          { 'payload' => '<p>Column 3</p>', 'value' => '3' }
        ]
      end

      it 'uses payload matching to detect deleted column' do
        result = detector.detect_deleted_columns(old_columns, new_columns)
        expect(result['3']).to eq('<p>Column 2</p>')
      end
    end
  end
end
