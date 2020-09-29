# frozen_string_literal: true

require 'rails_helper'

describe V1::QuestionGroups::Index, type: :serializer do
  subject { described_class.new(question_groups: question_groups) }

  let(:question_groups) { create_list(:question_group, 3, title: 'Test Title') }

  describe '#to_json' do
    it 'returns serialized hash' do
      result = subject.to_json

      expect(result[:question_groups].size).to eq 3
      expect(result[:question_groups][0][:title]).to eq 'Test Title'
    end
  end
end
