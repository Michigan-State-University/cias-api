# frozen_string_literal: true

RSpec.describe Question::Multiple, type: :model do
  describe 'Question::Multiple' do
    subject(:question_multiple) { build(:question_multiple) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_multiple) { create(:question_multiple) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_multiple.variable_clone_prefix([])[0]['variable']['name']).to eq('clone_answer_1')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_multiple.variable_clone_prefix(%w[clone_answer_1 clone1_answer_1])[0]['variable']['name']).to eq('clone2_answer_1')
        end
      end
    end
  end
end
