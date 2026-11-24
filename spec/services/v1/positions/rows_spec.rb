# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Positions::Rows do
  let(:id) { SecureRandom.uuid }
  let(:other_id) { SecureRandom.uuid }

  describe 'valid values' do
    subject(:rows) { described_class.new([{ id: id.upcase, position: 3 }, { id: other_id, position: '4' }]) }

    it 'returns downcased ids and integer positions' do
      expect(rows.ids).to eq [id, other_id]
      expect(rows.mapping(:position)).to eq(id => 3, other_id => 4)
    end

    it 'reads extra UUID keys' do
      rows = described_class.new([{ id: id, position: 1, question_group_id: other_id }], uuid_keys: %i[id question_group_id])

      expect(rows.column(:question_group_id)).to eq [other_id]
    end

    it 'accepts an empty list' do
      expect(described_class.new([]).ids).to eq []
    end
  end

  describe 'invalid values' do
    def expect_rejected(values, uuid_keys: %i[id])
      expect { described_class.new(values, uuid_keys: uuid_keys) }
        .to raise_error(ComplexException) { |error| expect(error.status_code).to eq :unprocessable_content }
    end

    it('rejects a position with letters') { expect_rejected([{ id: id, position: 'abc' }]) }
    it('rejects a decimal position') { expect_rejected([{ id: id, position: '1.5' }]) }
    it('rejects a float position') { expect_rejected([{ id: id, position: 1.5 }]) }
    it('rejects a missing position') { expect_rejected([{ id: id, position: nil }]) }
    it('rejects a position too big for the column') { expect_rejected([{ id: id, position: 2**31 }]) }
    it('rejects an id that is not a UUID') { expect_rejected([{ id: 'abc', position: 1 }]) }
    it('rejects an id containing a quote character') { expect_rejected([{ id: "#{id}'", position: 1 }]) }
    it('rejects an integer id') { expect_rejected([{ id: 1, position: 1 }]) }
    it('rejects a missing id') { expect_rejected([{ position: 1 }]) }
    it('rejects a list that is not an array') { expect_rejected({ '0' => { id: id, position: 1 } }) }
    it('rejects a missing list') { expect_rejected(nil) }
    it('rejects the same id twice') { expect_rejected([{ id: id, position: 1 }, { id: id.upcase, position: 2 }]) }

    it 'rejects an invalid extra UUID key' do
      expect_rejected([{ id: id, position: 1, question_group_id: 'abc' }], uuid_keys: %i[id question_group_id])
    end
  end
end
