# frozen_string_literal: true

RSpec.describe Question::Single, type: :model do
  describe 'Question::Single' do
    describe 'expected behaviour' do
      subject(:question_single) { build(:question_single) }

      it { should belong_to(:question_group) }
      it { should be_valid }

      describe 'instance methods' do
        let(:question_single) { create(:question_single) }

        describe '#variable_clone_prefix' do
          it 'sets correct variable with empty taken variables' do
            expect(question_single.variable_clone_prefix([])).to eq('clone_single_var')
          end

          it 'sets correct variable with passed taken variables' do
            expect(question_single.variable_clone_prefix(%w[clone_single_var clone1_single_var])).to eq('clone2_single_var')
          end
        end
      end
    end

    describe 'fails when body is empty' do
      let(:with_empty) { build(:question_single, :body_data_empty) }

      it { expect(with_empty.save).to eq false }
    end
  end
end
