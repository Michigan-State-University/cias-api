# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CappedSlug do
  describe 'class methods on including models' do
    describe SmsLinksUser do
      it 'reports slug_rounds as MAX_EXTENSIONS + 1' do
        expect(described_class.slug_rounds).to eq(3)
      end

      it 'reports max_slug_length as SLUG_LENGTH + MAX_EXTENSIONS * EXTENSION_LENGTH' do
        expect(described_class.max_slug_length).to eq(9)
      end

      it 'grows slug_length_for_round by EXTENSION_LENGTH each round' do
        expect(described_class.slug_length_for_round(0)).to eq(5)
        expect(described_class.slug_length_for_round(1)).to eq(7)
        expect(described_class.slug_length_for_round(2)).to eq(9)
      end
    end

    describe PredefinedUserParameter do
      it 'reports max_slug_length from its own SLUG_LENGTH' do
        expect(described_class.max_slug_length).to eq(8)
      end

      it 'reports slug_rounds as MAX_EXTENSIONS + 1' do
        expect(described_class.slug_rounds).to eq(3)
      end

      it 'grows slug_length_for_round by EXTENSION_LENGTH each round' do
        expect(described_class.slug_length_for_round(0)).to eq(4)
        expect(described_class.slug_length_for_round(1)).to eq(6)
        expect(described_class.slug_length_for_round(2)).to eq(8)
      end
    end
  end
end
