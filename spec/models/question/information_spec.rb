# frozen_string_literal: true

RSpec.describe Question::Information, type: :model do
  describe 'Question::' do
    subject(:question_information) { build(:question_information) }

    it { should belong_to(:question_group) }
    it { should be_valid }

    describe 'validation of question assignments' do
      let(:question) { build(:question_name, question_group: question_group) }

      it_behaves_like 'cannot be assigned to sms session'
      it_behaves_like 'can be assigned to classic session'
    end

    describe 'instance methods' do
      let(:question_information) { create(:question_information) }

      describe '#variable_clone_prefix' do
        it 'returns nil with empty taken variables' do
          expect(question_information.variable_clone_prefix([])).to eq(nil)
        end

        it 'returns nil with passed taken variables' do
          expect(question_information.variable_clone_prefix(%w[clone_question_slider_var
                                                               clone1_question_slider_var])).to eq(nil)
        end
      end

      describe 'translation' do
        let(:translator) { V1::Google::TranslationService.new }
        let(:source_language_name_short) { 'en' }
        let(:destination_language_name_short) { 'pl' }

        it '#translate_title' do
          question_information.translate_title(translator, source_language_name_short, destination_language_name_short)
          expect(question_information.title).to include('from=>en to=>pl text=>Information')
        end

        it '#translate_subtitle' do
          question_information.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
          expect(question_information.subtitle).to equal(nil)
        end
      end

      describe '#question_variables' do
        it 'returns empty variables list' do
          expect(question_information.question_variables).to match_array []
        end
      end
    end
  end
end
