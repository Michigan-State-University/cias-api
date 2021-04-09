# frozen_string_literal: true

RSpec.describe Question::Finish, type: :model do
  describe 'Question::Finish' do
    subject(:question_finish) { build(:question_finish) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_finish) { create(:question_finish) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_finish.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_finish.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq(nil)
        end
      end
    end
  end
end
