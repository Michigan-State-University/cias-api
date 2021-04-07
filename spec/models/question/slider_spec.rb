# frozen_string_literal: true

RSpec.describe Question::Slider, type: :model do
  describe 'Question::Slider' do
    subject(:question_slider) { build(:question_slider) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'instance methods' do
      let(:question_slider) { create(:question_slider) }

      describe '#variable_clone_prefix' do
        it 'sets correct variable with empty taken variables' do
          expect(question_slider.variable_clone_prefix([])).to eq('clone_question_slider_var')
        end

        it 'sets correct variable with passed taken variables' do
          expect(question_slider.variable_clone_prefix(%w[clone_question_slider_var clone1_question_slider_var])).to eq('clone2_question_slider_var')
        end
      end
    end
  end
end
