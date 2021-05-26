# frozen_string_literal: true

RSpec.describe Question::Feedback, type: :model do
  describe 'Question::Feedback' do
    subject(:question_feedback) { build(:question_feedback) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_feedback) { create(:question_feedback) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_feedback.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_feedback.variable_clone_prefix(%w[clone_question_slider_var
                                                            clone1_question_slider_var])).to eq(nil)
        end
      end
    end
  end
end
