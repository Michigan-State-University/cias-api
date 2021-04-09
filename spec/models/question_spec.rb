# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Question, type: :model do
  describe 'callbacks' do
    context 'after_create' do
      context 'when question has type Question::Finish' do
        let(:question_finish) { create(:question_finish) }

        it 'creates default block' do
          expect(question_finish['narrator']['blocks'].size).to eq(1)
        end
      end

      context 'when question has different type' do
        let(:question_single) { create(:question_single) }

        it 'does not create default block' do
          expect(question_single['narrator']['blocks'].size).to eq(0)
        end
      end
    end
  end

  describe 'instance methods' do
    let(:question) { create(:question_single) }

    it 'returns correct variable with clone index' do
      expect(question.variable_with_clone_index(%w[test test2 clone_test], 'test')).to eq('clone1_test')
      expect(question.variable_with_clone_index(%w[clone1_test clone3_test clone_test], 'test')).to eq('clone2_test')
      expect(question.variable_with_clone_index(%w[clone1_test clone_test clone2_test], 'test')).to eq('clone3_test')
    end
  end
end
