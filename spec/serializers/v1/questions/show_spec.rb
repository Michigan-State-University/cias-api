# frozen_string_literal: true

require 'rails_helper'

describe V1::Questions::Show, type: :serializer do
  subject { described_class.new(question: question) }

  let(:question) { create(:question_free_response, subtitle: 'Test Subtitle') }

  describe '#to_json' do
    it 'returns serialized hash' do
      result = subject.to_json

      expect(result[:subtitle]).to eq 'Test Subtitle'
    end
  end
end
