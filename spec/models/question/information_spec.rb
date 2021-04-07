# frozen_string_literal: true

RSpec.describe Question::Information, type: :model do
  describe 'Question::' do
    subject(:question_information) { build(:question_information) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_information) { create(:question_information) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_information.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_information.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq(nil)
        end
      end
    end
  end
end
