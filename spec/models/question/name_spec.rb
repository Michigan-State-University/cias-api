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

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_name.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_name.title).to include('from=>en to=>pl text=>Name screen')
        end

        it '#translate_subtitle' do
          question_name.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_name.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns correct variables' do
          expect(question_name.question_variables).to match_array ['.:name:.']
        end

        it 'returns correct amount of variables' do
          expect(question_name.question_variables.size).to eq 1
        end
      end
    end
  end
end
