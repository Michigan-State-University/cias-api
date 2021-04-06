# frozen_string_literal: true

RSpec.describe Question::BarGraph, type: :model do
  describe 'Question::BarGraph' do
    subject(:question_bar_graph) { build(:question_bar_graph) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_bar_graph) { create(:question_bar_graph) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_bar_graph.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_bar_graph.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq(nil)
        end
      end
    end
  end
end
