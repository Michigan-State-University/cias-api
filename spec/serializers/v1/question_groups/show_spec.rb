# frozen_string_literal: true

require 'rails_helper'

describe V1::QuestionGroups::Show, type: :serializer do
  subject { described_class.new(question_group: question_group) }

  let(:question_group) { create(:question_group, title: 'Test Title') }

  describe '#to_json' do
    it 'returns serialized hash' do
      result = subject.to_json

      expect(result[:title]).to eq 'Test Title'
    end
  end
end
