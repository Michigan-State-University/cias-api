# frozen_string_literal: true

RSpec.describe Question::Grid, type: :model do
  describe 'Question::Grid' do
    subject(:question_grid) { build(:question_grid) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_grid) { create(:question_grid) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_grid.variable_clone_prefix([])[0]['variable']['name']).to eq('clone_row1')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_grid.variable_clone_prefix(%w[clone_row1 clone1_row1])[0]['variable']['name']).to eq('clone2_row1')
        end
      end
    end
  end
end
