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
          expect(question_slider.variable_clone_prefix(%w[clone_question_slider_var
                                                          clone1_question_slider_var])).to eq('clone2_question_slider_var')
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_slider.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_slider.title).to include('from=>en to=>pl text=>Slider')
        end

        it '#translate_subtitle' do
          question_slider.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_slider.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns correct variable names list' do
          expect(question_slider.question_variables).to match_array ['question_slider_var']
        end

        it 'returns correct amount of variables' do
          expect(question_slider.question_variables.size).to eq 1
        end
      end
    end
  end
end
