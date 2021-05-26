# frozen_string_literal: true

RSpec.describe Question::Name, type: :model do
  describe 'Question::Name' do
    subject(:question_name) { build(:question_name) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_name) { create(:question_name) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_name.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_name.variable_clone_prefix(%w[clone_question_slider_var
                                                        clone1_question_slider_var])).to eq(nil)
        end
      end
    end
  end
end
