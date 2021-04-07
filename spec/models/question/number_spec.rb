# frozen_string_literal: true

RSpec.describe Question::Number, type: :model do
  describe 'Question::Number' do
    subject(:question_number) { build(:question_number) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_number) { create(:question_number) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_number.variable_clone_prefix([])).to eq('clone_number_var')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_number.variable_clone_prefix(%w[clone_number_var clone1_number_var])).to eq('clone2_number_var')
        end
      end
    end
  end
end
